package chats_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type chatSummary struct {
	RoomID string `json:"room_id"`
	Name   string `json:"name"`
}

type deleteChatResponse struct {
	Success bool `json:"success"`
}

func listChats(t *testing.T, c *testutil.Client, token string) []chatSummary {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/chats", nil, token)
	if err != nil {
		t.Fatalf("list chats http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list chats status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []chatSummary
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list chats decode: %v body=%s", err, string(body))
	}
	return items
}

func TestChats_ListRequiresAuth(t *testing.T) {
	c := testutil.NewClient()
	resp, body, err := c.DoJSON("GET", "/chats", nil, "")
	if err != nil {
		t.Fatalf("list chats http error: %v", err)
	}
	if resp.StatusCode != 401 {
		t.Fatalf("expected status=401, got %d body=%s", resp.StatusCode, string(body))
	}
}

func TestChats_ListIncludesRoom_AndDeleteChat(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user3 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	_ = testutil.Login(t, c, user2.Username, pass)
	login3 := testutil.Login(t, c, user3.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-chats-"+time.Now().Format("150405"), []string{user2.ID})

	items := listChats(t, c, login1.Token)
	if !slices.ContainsFunc(items, func(cs chatSummary) bool { return cs.RoomID == roomID }) {
		t.Fatalf("expected chats to contain room_id=%s, got %v", roomID, items)
	}

	// 非成员删除：应返回 404（后端用 NotFound 表达无权限/不存在）
	resp403, body403, err := c.DoJSON("DELETE", "/chats/"+roomID, nil, login3.Token)
	if err != nil {
		t.Fatalf("delete chat (non-member) http error: %v", err)
	}
	if resp403.StatusCode != 404 {
		t.Fatalf("expected non-member delete status=404, got %d body=%s", resp403.StatusCode, string(body403))
	}

	respDel, bodyDel, err := c.DoJSON("DELETE", "/chats/"+roomID, nil, login1.Token)
	if err != nil {
		t.Fatalf("delete chat http error: %v", err)
	}
	if respDel.StatusCode != 200 {
		t.Fatalf("delete chat status=%d body=%s", respDel.StatusCode, string(bodyDel))
	}
	var del deleteChatResponse
	if err := testutil.DecodeJSON(bodyDel, &del); err != nil {
		t.Fatalf("delete chat decode: %v body=%s", err, string(bodyDel))
	}
	if !del.Success {
		t.Fatalf("expected delete success=true, got false body=%s", string(bodyDel))
	}

	items2 := listChats(t, c, login1.Token)
	if slices.ContainsFunc(items2, func(cs chatSummary) bool { return cs.RoomID == roomID }) {
		t.Fatalf("expected room_id=%s to be removed after delete, got %v", roomID, items2)
	}
}

