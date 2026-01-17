package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type createJoinRequestResp struct {
	Request struct {
		ID string `json:"id"`
	} `json:"request"`
}

type ensureChatResp struct {
	RoomID string `json:"room_id"`
}

func TestRooms_JoinGroup_RequiresApprovalWhenEnabled(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	existingMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	applicant := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	applicantLogin := testutil.Login(t, c, applicant.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-join-approval-"+time.Now().Format("150405"), []string{existingMember.ID})

	// 开启入群审批
	resp0, body0, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/settings", map[string]any{
		"join_approval_required": true,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("enable join_approval_required http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("enable join_approval_required status=%d body=%s", resp0.StatusCode, string(body0))
	}

	// 未审批：无法 join
	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/join", nil, applicantLogin.Token)
	if err != nil {
		t.Fatalf("applicant join group (no request) http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected applicant join group (no request)=403, got %d body=%s", resp1.StatusCode, string(body1))
	}

	// 创建 join request
	resp2, body2, err := c.DoJSON("POST", "/rooms/"+roomID+"/join-requests", map[string]any{
		"message": "pls",
	}, applicantLogin.Token)
	if err != nil {
		t.Fatalf("create join request http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("create join request status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var jr createJoinRequestResp
	if err := testutil.DecodeJSON(body2, &jr); err != nil {
		t.Fatalf("decode create join request: %v body=%s", err, string(body2))
	}
	if jr.Request.ID == "" {
		t.Fatalf("expected join request id, got empty body=%s", string(body2))
	}

	// pending：仍无法 join
	resp3, body3, err := c.DoJSON("POST", "/rooms/"+roomID+"/join", nil, applicantLogin.Token)
	if err != nil {
		t.Fatalf("applicant join group (pending) http error: %v", err)
	}
	if resp3.StatusCode != 403 {
		t.Fatalf("expected applicant join group (pending)=403, got %d body=%s", resp3.StatusCode, string(body3))
	}

	// 审批通过
	resp4, body4, err := c.DoJSON("POST", "/rooms/"+roomID+"/join-requests/"+jr.Request.ID+"/review", map[string]any{
		"status": "approved",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("review join request http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("review join request status=%d body=%s", resp4.StatusCode, string(body4))
	}

	// 允许 join
	resp5, body5, err := c.DoJSON("POST", "/rooms/"+roomID+"/join", nil, applicantLogin.Token)
	if err != nil {
		t.Fatalf("applicant join group (approved) http error: %v", err)
	}
	if resp5.StatusCode != 200 {
		t.Fatalf("expected applicant join group (approved)=200, got %d body=%s", resp5.StatusCode, string(body5))
	}

	members := listMembers(t, c, ownerLogin.Token, roomID)
	if !slices.ContainsFunc(members, func(m memberInfo) bool { return m.UserID == applicant.ID }) {
		t.Fatalf("expected members contain applicant=%s, got %v", applicant.ID, members)
	}
}

func TestRooms_Join_PrivateRoomForbiddenForNonMember(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	outsider := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	outsiderLogin := testutil.Login(t, c, outsider.Username, pass)

	// 创建/确保私聊房间
	resp0, body0, err := c.DoJSON("POST", "/friends/"+user2.ID+"/chat", nil, login1.Token)
	if err != nil {
		t.Fatalf("ensure private chat http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("ensure private chat status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var chat ensureChatResp
	if err := testutil.DecodeJSON(body0, &chat); err != nil {
		t.Fatalf("decode ensure private chat: %v body=%s", err, string(body0))
	}
	if chat.RoomID == "" {
		t.Fatalf("expected room_id non-empty, body=%s", string(body0))
	}

	// outsider 不能 join 私聊房间
	resp1, body1, err := c.DoJSON("POST", "/rooms/"+chat.RoomID+"/join", nil, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider join private room http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected outsider join private room=403, got %d body=%s", resp1.StatusCode, string(body1))
	}
}
