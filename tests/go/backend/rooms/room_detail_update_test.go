package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type roomDetailResponse struct {
	Success bool `json:"success"`
	Room    struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Owner  string `json:"owner_id"`
		RoomTy string `json:"room_type"`
	} `json:"room"`
}

type updateRoomResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Room    *struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"room"`
}

func getRoomDetail(t *testing.T, c *testutil.Client, token, roomID string) roomDetailResponse {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID, nil, token)
	if err != nil {
		t.Fatalf("get room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get room status=%d body=%s", resp.StatusCode, string(body))
	}
	var out roomDetailResponse
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("get room decode: %v body=%s", err, string(body))
	}
	if !out.Success {
		t.Fatalf("get room success=false body=%s", string(body))
	}
	return out
}

func TestRooms_DetailAndMembers_RequireMembership(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	outsider := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	outsiderLogin := testutil.Login(t, c, outsider.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-room-detail-"+time.Now().Format("150405"), []string{member.ID})

	// outsider: room detail
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID, nil, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider get room http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected outsider get room status=403, got %d body=%s", resp.StatusCode, string(body))
	}

	// outsider: room members
	resp, body, err = c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider list members http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected outsider list members status=403, got %d body=%s", resp.StatusCode, string(body))
	}

	detail := getRoomDetail(t, c, ownerLogin.Token, roomID)
	if detail.Room.ID != roomID {
		t.Fatalf("expected room.id=%s, got %s", roomID, detail.Room.ID)
	}

	members := listMembers(t, c, ownerLogin.Token, roomID)
	if !slices.ContainsFunc(members, func(m memberInfo) bool { return m.UserID == owner.ID }) {
		t.Fatalf("expected members contain owner=%s, got %v", owner.ID, members)
	}
	if !slices.ContainsFunc(members, func(m memberInfo) bool { return m.UserID == member.ID }) {
		t.Fatalf("expected members contain member=%s, got %v", member.ID, members)
	}
}

func TestRooms_UpdateRoom_OnlyOwnerOrAdmin(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-room-upd-"+time.Now().Format("150405"), []string{member.ID})

	// 普通成员不允许更新房间
	resp, body, err := c.DoJSON("PATCH", "/rooms/"+roomID, map[string]any{"name": "forbidden"}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member update room http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected member update room status=403, got %d body=%s", resp.StatusCode, string(body))
	}

	newName := "go-room-upd-new-" + time.Now().Format("150405.000000000")
	resp2, body2, err := c.DoJSON("PATCH", "/rooms/"+roomID, map[string]any{"name": newName}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner update room http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("owner update room status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var upd updateRoomResponse
	if err := testutil.DecodeJSON(body2, &upd); err != nil {
		t.Fatalf("owner update room decode: %v body=%s", err, string(body2))
	}
	if !upd.Success || upd.Room == nil || upd.Room.Name != newName {
		t.Fatalf("unexpected update room resp: %+v body=%s", upd, string(body2))
	}

	detail := getRoomDetail(t, c, ownerLogin.Token, roomID)
	if detail.Room.Name != newName {
		t.Fatalf("expected room name=%q after update, got %q", newName, detail.Room.Name)
	}
}

