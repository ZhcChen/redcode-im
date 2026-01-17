package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type joinLeaveResp struct {
	OK bool `json:"ok"`
}

type myRoom struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	RoomType string `json:"room_type"`
}

func listMyRooms(t *testing.T, c *testutil.Client, token string) []myRoom {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms", nil, token)
	if err != nil {
		t.Fatalf("list my rooms http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list my rooms status=%d body=%s", resp.StatusCode, string(body))
	}
	var out []myRoom
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("list my rooms decode: %v body=%s", err, string(body))
	}
	return out
}

func joinRoom(t *testing.T, c *testutil.Client, token, roomID string) {
	t.Helper()
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/join", map[string]any{}, token)
	if err != nil {
		t.Fatalf("join room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("join room status=%d body=%s", resp.StatusCode, string(body))
	}
	var out joinLeaveResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("join room decode: %v body=%s", err, string(body))
	}
	if !out.OK {
		t.Fatalf("join room not ok: %+v", out)
	}
}

func leaveRoom(t *testing.T, c *testutil.Client, token, roomID string) {
	t.Helper()
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/leave", map[string]any{}, token)
	if err != nil {
		t.Fatalf("leave room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("leave room status=%d body=%s", resp.StatusCode, string(body))
	}
	var out joinLeaveResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("leave room decode: %v body=%s", err, string(body))
	}
	if !out.OK {
		t.Fatalf("leave room not ok: %+v", out)
	}
}

func TestRooms_JoinLeave_PublicRoom(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	userLogin := testutil.Login(t, c, user.Username, pass)

	roomID := testutil.CreatePublicRoom(t, c, ownerLogin.Token, "go-public-"+time.Now().Format("150405"))

	// 初始 user 不在房间列表里
	before := listMyRooms(t, c, userLogin.Token)
	if slices.ContainsFunc(before, func(r myRoom) bool { return r.ID == roomID }) {
		t.Fatalf("expected user not in room before join, got %+v", before)
	}

	joinRoom(t, c, userLogin.Token, roomID)

	afterJoin := listMyRooms(t, c, userLogin.Token)
	if !slices.ContainsFunc(afterJoin, func(r myRoom) bool { return r.ID == roomID && r.RoomType == "public" }) {
		t.Fatalf("expected joined room in list, got %+v", afterJoin)
	}

	leaveRoom(t, c, userLogin.Token, roomID)

	afterLeave := listMyRooms(t, c, userLogin.Token)
	if slices.ContainsFunc(afterLeave, func(r myRoom) bool { return r.ID == roomID }) {
		t.Fatalf("expected room removed after leave, got %+v", afterLeave)
	}
}

