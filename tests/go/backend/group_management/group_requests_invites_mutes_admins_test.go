package group_management_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type joinRequestResponse struct {
	Request struct {
		ID          string `json:"id"`
		RoomID      string `json:"room_id"`
		ApplicantID string `json:"applicant_id"`
		Status      int    `json:"status"`
	} `json:"request"`
}

type listJoinRequestsResponse struct {
	Requests []struct {
		ID          string `json:"id"`
		ApplicantID string `json:"applicant_id"`
		Status      int    `json:"status"`
	} `json:"requests"`
}

type invitationsResponse struct {
	Invitations []struct {
		ID        string `json:"id"`
		RoomID    string `json:"room_id"`
		InviterID string `json:"inviter_id"`
		InviteeID string `json:"invitee_id"`
		Status    int    `json:"status"`
	} `json:"invitations"`
}

type listAdminsResponse struct {
	Admins []struct {
		ID     string `json:"id"`
		RoomID string `json:"room_id"`
		AdminID string `json:"admin_id"`
		Role   string `json:"role"`
	} `json:"admins"`
}

type appointAdminResponse struct {
	Admin struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		AdminID string `json:"admin_id"`
		Role    string `json:"role"`
	} `json:"admin"`
}

type muteResponse struct {
	Mute struct {
		ID     string `json:"id"`
		RoomID string `json:"room_id"`
		UserID string `json:"user_id"`
		Reason *string `json:"reason"`
	} `json:"mute"`
}

type listMutedUsersResponse struct {
	Mutes []struct {
		UserID string `json:"user_id"`
		Reason *string `json:"reason"`
	} `json:"mutes"`
}

type operationLogsResponse struct {
	Logs []struct {
		OperationType string `json:"operation_type"`
	} `json:"logs"`
	Total int64 `json:"total"`
}

type groupDetailResponse struct {
	Info struct {
		ID                   string `json:"id"`
		Name                 string `json:"name"`
		JoinApprovalRequired bool   `json:"join_approval_required"`
		MemberCanInvite      bool   `json:"member_can_invite"`
		GlobalMuteEnabled    bool   `json:"global_mute_enabled"`
	} `json:"info"`
}

func TestGroupManagement_JoinRequests_CreateListReview_Permissions(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	applicant := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)
	applicantLogin := testutil.Login(t, c, applicant.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-jr-"+time.Now().Format("150405"), []string{member.ID})

	// applicant creates join request
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/join-requests", map[string]any{
		"message": "please",
	}, applicantLogin.Token)
	if err != nil {
		t.Fatalf("create join request http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("create join request status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var created joinRequestResponse
	if err := testutil.DecodeJSON(body0, &created); err != nil {
		t.Fatalf("decode create join request: %v body=%s", err, string(body0))
	}
	if created.Request.ID == "" || created.Request.ApplicantID != applicant.ID {
		t.Fatalf("unexpected join request resp: %+v body=%s", created.Request, string(body0))
	}
	if created.Request.Status != 0 {
		t.Fatalf("expected status=0(pending), got %d body=%s", created.Request.Status, string(body0))
	}

	// non-manager cannot list join requests
	resp1, body1, err := c.DoJSON("GET", "/rooms/"+roomID+"/join-requests", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("list join requests (non-manager) http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected list join requests (non-manager)=403, got %d body=%s", resp1.StatusCode, string(body1))
	}

	resp2, body2, err := c.DoJSON("GET", "/rooms/"+roomID+"/join-requests", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list join requests http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("list join requests status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var list listJoinRequestsResponse
	if err := testutil.DecodeJSON(body2, &list); err != nil {
		t.Fatalf("decode list join requests: %v body=%s", err, string(body2))
	}
	if !slices.ContainsFunc(list.Requests, func(r struct {
		ID          string `json:"id"`
		ApplicantID string `json:"applicant_id"`
		Status      int    `json:"status"`
	}) bool { return r.ID == created.Request.ID && r.ApplicantID == applicant.ID }) {
		t.Fatalf("expected join request in list, got %+v", list.Requests)
	}

	// review: non-manager forbidden
	resp3, body3, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/join-requests/"+created.Request.ID+"/review", map[string]any{
		"status": "approved",
	}, memberLogin.Token)
	if err != nil {
		t.Fatalf("review join request (non-manager) http error: %v", err)
	}
	if resp3.StatusCode != 403 {
		t.Fatalf("expected review join request (non-manager)=403, got %d body=%s", resp3.StatusCode, string(body3))
	}

	resp4, body4, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/join-requests/"+created.Request.ID+"/review", map[string]any{
		"status":         "approved",
		"review_message": "ok",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("review join request http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("review join request status=%d body=%s", resp4.StatusCode, string(body4))
	}
	var reviewed joinRequestResponse
	if err := testutil.DecodeJSON(body4, &reviewed); err != nil {
		t.Fatalf("decode reviewed join request: %v body=%s", err, string(body4))
	}
	if reviewed.Request.Status != 1 {
		t.Fatalf("expected reviewed status=1(approved), got %d body=%s", reviewed.Request.Status, string(body4))
	}
}

func TestGroupManagement_Invitations_AcceptAddsMember_AndGuardsInvitee(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	invitee := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	attacker := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)
	inviteeLogin := testutil.Login(t, c, invitee.Username, pass)
	attackerLogin := testutil.Login(t, c, attacker.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-invite-"+time.Now().Format("150405"), []string{member.ID})

	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/invitations", map[string]any{
		"user_ids": []string{invitee.ID},
		"message":  "join us",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("create invitations http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("create invitations status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var inv invitationsResponse
	if err := testutil.DecodeJSON(body0, &inv); err != nil {
		t.Fatalf("decode invitations resp: %v body=%s", err, string(body0))
	}
	if len(inv.Invitations) != 1 || inv.Invitations[0].ID == "" || inv.Invitations[0].InviteeID != invitee.ID {
		t.Fatalf("unexpected invitations resp: %+v body=%s", inv, string(body0))
	}

	invID := inv.Invitations[0].ID

	// 非 invitee 不能响应该邀请
	resp1, body1, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/invitations/"+invID+"/respond", map[string]any{
		"status": "accepted",
	}, attackerLogin.Token)
	if err != nil {
		t.Fatalf("respond invitation (attacker) http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected respond invitation (attacker)=403, got %d body=%s", resp1.StatusCode, string(body1))
	}

	resp2, body2, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/invitations/"+invID+"/respond", map[string]any{
		"status": "accepted",
	}, inviteeLogin.Token)
	if err != nil {
		t.Fatalf("respond invitation http error: %v", err)
	}
	if resp2.StatusCode != 204 {
		t.Fatalf("expected respond invitation status=204, got %d body=%s", resp2.StatusCode, string(body2))
	}

	// 被邀请用户应成为群成员
	resp3, body3, err := c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, inviteeLogin.Token)
	if err != nil {
		t.Fatalf("invitee list members http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("invitee list members status=%d body=%s", resp3.StatusCode, string(body3))
	}

	// 二次响应应失败（已响应）
	resp4, body4, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/invitations/"+invID+"/respond", map[string]any{
		"status": "accepted",
	}, inviteeLogin.Token)
	if err != nil {
		t.Fatalf("respond invitation again http error: %v", err)
	}
	if resp4.StatusCode != 404 {
		t.Fatalf("expected respond invitation again status=404, got %d body=%s", resp4.StatusCode, string(body4))
	}

	// 普通成员在 member_can_invite=false 时不能邀请
	resp5, body5, err := c.DoJSON("POST", "/rooms/"+roomID+"/invitations", map[string]any{
		"user_ids": []string{attacker.ID},
	}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member create invitations http error: %v", err)
	}
	if resp5.StatusCode != 403 {
		t.Fatalf("expected member create invitations status=403 when member_can_invite=false, got %d body=%s", resp5.StatusCode, string(body5))
	}

	// 开启 member_can_invite 后，普通成员可以邀请，但必须是房间成员
	_, _, _ = c.DoJSON("PATCH", "/rooms/"+roomID+"/settings", map[string]any{"member_can_invite": true}, ownerLogin.Token)
	resp6, body6, err := c.DoJSON("POST", "/rooms/"+roomID+"/invitations", map[string]any{
		"user_ids": []string{attacker.ID},
	}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member create invitations (allowed) http error: %v", err)
	}
	if resp6.StatusCode != 200 {
		t.Fatalf("expected member create invitations status=200 when member_can_invite=true, got %d body=%s", resp6.StatusCode, string(body6))
	}
}

func TestGroupManagement_Mutes_GlobalMute_AndOperationLogs(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	adminCandidate := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	adminLogin := testutil.Login(t, c, adminCandidate.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-mute-"+time.Now().Format("150405"), []string{adminCandidate.ID, member.ID})

	// 非群主不能任命管理员
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/admins", map[string]any{
		"user_id": member.ID,
		"role":    "admin",
	}, adminLogin.Token)
	if err != nil {
		t.Fatalf("appoint admin (non-owner) http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected appoint admin (non-owner)=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/admins", map[string]any{
		"user_id": adminCandidate.ID,
		"role":    "admin",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("appoint admin http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("appoint admin status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var appointed appointAdminResponse
	if err := testutil.DecodeJSON(body1, &appointed); err != nil {
		t.Fatalf("decode appoint admin: %v body=%s", err, string(body1))
	}
	if appointed.Admin.AdminID != adminCandidate.ID || appointed.Admin.Role == "" {
		t.Fatalf("unexpected appoint admin resp: %+v body=%s", appointed.Admin, string(body1))
	}

	respList, bodyList, err := c.DoJSON("GET", "/rooms/"+roomID+"/admins", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list admins http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list admins status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var admins listAdminsResponse
	if err := testutil.DecodeJSON(bodyList, &admins); err != nil {
		t.Fatalf("decode list admins: %v body=%s", err, string(bodyList))
	}
	if !slices.ContainsFunc(admins.Admins, func(a struct {
		ID     string `json:"id"`
		RoomID string `json:"room_id"`
		AdminID string `json:"admin_id"`
		Role   string `json:"role"`
	}) bool { return a.AdminID == adminCandidate.ID }) {
		t.Fatalf("expected admin in list, got %+v", admins.Admins)
	}

	// mute user
	reason := "go-test-mute"
	resp2, body2, err := c.DoJSON("POST", "/rooms/"+roomID+"/mutes", map[string]any{
		"user_id":             member.ID,
		"reason":              reason,
		"duration_hours":      1,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("mute user http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("mute user status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var mr muteResponse
	if err := testutil.DecodeJSON(body2, &mr); err != nil {
		t.Fatalf("decode mute user: %v body=%s", err, string(body2))
	}
	if mr.Mute.UserID != member.ID || mr.Mute.Reason == nil || *mr.Mute.Reason != reason {
		t.Fatalf("unexpected mute resp: %+v body=%s", mr.Mute, string(body2))
	}

	// muted member cannot send message
	resp3, _, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", map[string]any{"content": "hi"}, memberLogin.Token)
	if err != nil {
		t.Fatalf("muted member send message http error: %v", err)
	}
	if resp3.StatusCode != 403 {
		t.Fatalf("expected muted member send message=403, got %d", resp3.StatusCode)
	}

	// list muted users: only manager
	resp4, body4, err := c.DoJSON("GET", "/rooms/"+roomID+"/mutes", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list mutes http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("list mutes status=%d body=%s", resp4.StatusCode, string(body4))
	}
	var lm listMutedUsersResponse
	if err := testutil.DecodeJSON(body4, &lm); err != nil {
		t.Fatalf("decode list mutes: %v body=%s", err, string(body4))
	}
	if !slices.ContainsFunc(lm.Mutes, func(m struct {
		UserID string `json:"user_id"`
		Reason *string `json:"reason"`
	}) bool { return m.UserID == member.ID }) {
		t.Fatalf("expected muted user in list, got %+v", lm.Mutes)
	}

	resp4b, body4b, err := c.DoJSON("GET", "/rooms/"+roomID+"/mutes", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("list mutes (member) http error: %v", err)
	}
	if resp4b.StatusCode != 403 {
		t.Fatalf("expected list mutes (member)=403, got %d body=%s", resp4b.StatusCode, string(body4b))
	}

	// unmute by admin
	resp5, body5, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/mutes/"+member.ID, nil, adminLogin.Token)
	if err != nil {
		t.Fatalf("unmute user http error: %v", err)
	}
	if resp5.StatusCode != 204 {
		t.Fatalf("expected unmute status=204, got %d body=%s", resp5.StatusCode, string(body5))
	}

	// after unmute, member can send
	resp6, body6, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", map[string]any{"content": "ok"}, memberLogin.Token)
	if err != nil {
		t.Fatalf("unmuted member send message http error: %v", err)
	}
	if resp6.StatusCode != 200 {
		t.Fatalf("expected unmuted member send message=200, got %d body=%s", resp6.StatusCode, string(body6))
	}

	// enable global mute: member cannot send, admin can
	resp7, body7, err := c.DoJSON("POST", "/rooms/"+roomID+"/mutes/global", map[string]any{
		"enabled":          true,
		"reason":           "go-global",
		"duration_minutes": 5,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("enable global mute http error: %v", err)
	}
	if resp7.StatusCode != 200 {
		t.Fatalf("enable global mute status=%d body=%s", resp7.StatusCode, string(body7))
	}

	resp8, _, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", map[string]any{"content": "blocked"}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member send during global mute http error: %v", err)
	}
	if resp8.StatusCode != 403 {
		t.Fatalf("expected member send during global mute=403, got %d", resp8.StatusCode)
	}

	resp9, body9, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", map[string]any{"content": "admin ok"}, adminLogin.Token)
	if err != nil {
		t.Fatalf("admin send during global mute http error: %v", err)
	}
	if resp9.StatusCode != 200 {
		t.Fatalf("expected admin send during global mute=200, got %d body=%s", resp9.StatusCode, string(body9))
	}

	// operation logs should include key operations
	resp10, body10, err := c.DoJSON("GET", "/rooms/"+roomID+"/operation-logs?limit=20&offset=0", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list operation logs http error: %v", err)
	}
	if resp10.StatusCode != 200 {
		t.Fatalf("list operation logs status=%d body=%s", resp10.StatusCode, string(body10))
	}
	var logs operationLogsResponse
	if err := testutil.DecodeJSON(body10, &logs); err != nil {
		t.Fatalf("decode operation logs: %v body=%s", err, string(body10))
	}
	if logs.Total <= 0 || len(logs.Logs) == 0 {
		t.Fatalf("expected logs non-empty, got %+v", logs)
	}
	if !slices.ContainsFunc(logs.Logs, func(l struct{ OperationType string `json:"operation_type"` }) bool { return l.OperationType == "mute_user" }) {
		t.Fatalf("expected logs include mute_user, got %+v", logs.Logs)
	}

	// group detail should be readable and reflect settings (global mute enabled)
	resp11, body11, err := c.DoJSON("GET", "/rooms/"+roomID+"/detail", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("get group detail http error: %v", err)
	}
	if resp11.StatusCode != 200 {
		t.Fatalf("get group detail status=%d body=%s", resp11.StatusCode, string(body11))
	}
	var gd groupDetailResponse
	if err := testutil.DecodeJSON(body11, &gd); err != nil {
		t.Fatalf("decode group detail: %v body=%s", err, string(body11))
	}
	if gd.Info.ID != roomID || !gd.Info.GlobalMuteEnabled {
		t.Fatalf("unexpected group detail info: %+v body=%s", gd.Info, string(body11))
	}
}

func TestGroupManagement_JoinRequests_ReviewPOSTAlias_RejectPreventsJoin(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	seedMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	applicant := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	applicantLogin := testutil.Login(t, c, applicant.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-jr-reject-"+time.Now().Format("150405"), []string{seedMember.ID})

	// 启用入群审批
	respSettings, bodySettings, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/settings", map[string]any{
		"join_approval_required": true,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("update group settings http error: %v", err)
	}
	if respSettings.StatusCode != 200 {
		t.Fatalf("update group settings status=%d body=%s", respSettings.StatusCode, string(bodySettings))
	}

	// applicant creates join request
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/join-requests", map[string]any{
		"message": "please",
	}, applicantLogin.Token)
	if err != nil {
		t.Fatalf("create join request http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("create join request status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var created joinRequestResponse
	if err := testutil.DecodeJSON(body0, &created); err != nil {
		t.Fatalf("decode create join request: %v body=%s", err, string(body0))
	}
	if created.Request.ID == "" || created.Request.ApplicantID != applicant.ID {
		t.Fatalf("unexpected join request resp: %+v body=%s", created.Request, string(body0))
	}

	// owner reviews join request via POST alias (Flutter 现状用 POST)
	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/join-requests/"+created.Request.ID+"/review", map[string]any{
		"status":         "rejected",
		"review_message": "no",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("review join request (POST) http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("review join request (POST) status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var reviewed joinRequestResponse
	if err := testutil.DecodeJSON(body1, &reviewed); err != nil {
		t.Fatalf("decode reviewed join request: %v body=%s", err, string(body1))
	}
	if reviewed.Request.Status != 2 {
		t.Fatalf("expected reviewed status=2(rejected), got %d body=%s", reviewed.Request.Status, string(body1))
	}

	// applicant cannot join the group (approval required but not approved)
	resp2, body2, err := c.DoJSON("POST", "/rooms/"+roomID+"/join", nil, applicantLogin.Token)
	if err != nil {
		t.Fatalf("join room http error: %v", err)
	}
	if resp2.StatusCode != 403 {
		t.Fatalf("expected join room=403, got %d body=%s", resp2.StatusCode, string(body2))
	}
}

func TestGroupManagement_Invitations_DeclineDoesNotAddMember(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	seedMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	invitee := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	inviteeLogin := testutil.Login(t, c, invitee.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-invite-decline-"+time.Now().Format("150405"), []string{seedMember.ID})

	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/invitations", map[string]any{
		"user_ids": []string{invitee.ID},
		"message":  "join us",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("create invitations http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("create invitations status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var inv invitationsResponse
	if err := testutil.DecodeJSON(body0, &inv); err != nil {
		t.Fatalf("decode invitations resp: %v body=%s", err, string(body0))
	}
	if len(inv.Invitations) != 1 || inv.Invitations[0].ID == "" || inv.Invitations[0].InviteeID != invitee.ID {
		t.Fatalf("unexpected invitations resp: %+v body=%s", inv, string(body0))
	}
	invID := inv.Invitations[0].ID

	resp1, body1, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/invitations/"+invID+"/respond", map[string]any{
		"status": "declined",
	}, inviteeLogin.Token)
	if err != nil {
		t.Fatalf("respond invitation (decline) http error: %v", err)
	}
	if resp1.StatusCode != 204 {
		t.Fatalf("expected respond invitation (decline) status=204, got %d body=%s", resp1.StatusCode, string(body1))
	}

	// invitee should NOT become group member
	resp2, body2, err := c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list members http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("list members status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var members []struct {
		UserID string `json:"user_id"`
	}
	if err := testutil.DecodeJSON(body2, &members); err != nil {
		t.Fatalf("decode members: %v body=%s", err, string(body2))
	}
	if slices.ContainsFunc(members, func(m struct{ UserID string `json:"user_id"` }) bool { return m.UserID == invitee.ID }) {
		t.Fatalf("expected invitee not in members, got %+v", members)
	}

	// 二次响应应失败（已响应）
	resp3, body3, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/invitations/"+invID+"/respond", map[string]any{
		"status": "accepted",
	}, inviteeLogin.Token)
	if err != nil {
		t.Fatalf("respond invitation again http error: %v", err)
	}
	if resp3.StatusCode != 404 {
		t.Fatalf("expected respond invitation again status=404, got %d body=%s", resp3.StatusCode, string(body3))
	}
}

func TestGroupManagement_Admins_RemoveAdmin_OwnerOnly(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	adminCandidate := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	adminLogin := testutil.Login(t, c, adminCandidate.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-admin-remove-"+time.Now().Format("150405"), []string{adminCandidate.ID})

	// owner appoints admin
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/admins", map[string]any{
		"user_id": adminCandidate.ID,
		"role":    "admin",
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("appoint admin http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("appoint admin status=%d body=%s", resp0.StatusCode, string(body0))
	}

	// non-owner cannot remove
	resp1, body1, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/admins/"+adminCandidate.ID, nil, adminLogin.Token)
	if err != nil {
		t.Fatalf("remove admin (non-owner) http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected remove admin (non-owner)=403, got %d body=%s", resp1.StatusCode, string(body1))
	}

	resp2, body2, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/admins/"+adminCandidate.ID, nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("remove admin http error: %v", err)
	}
	if resp2.StatusCode != 204 {
		t.Fatalf("expected remove admin status=204, got %d body=%s", resp2.StatusCode, string(body2))
	}

	resp3, body3, err := c.DoJSON("GET", "/rooms/"+roomID+"/admins", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("list admins http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("list admins status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var admins listAdminsResponse
	if err := testutil.DecodeJSON(body3, &admins); err != nil {
		t.Fatalf("decode list admins: %v body=%s", err, string(body3))
	}
	if slices.ContainsFunc(admins.Admins, func(a struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		AdminID string `json:"admin_id"`
		Role    string `json:"role"`
	}) bool { return a.AdminID == adminCandidate.ID }) {
		t.Fatalf("expected admin removed, got %+v", admins.Admins)
	}
}
