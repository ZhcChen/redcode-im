package friends_test

import (
	"net/url"
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type friendRequestInfo struct {
	ID        string `json:"id"`
	Requester struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"requester"`
	Addressee struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"addressee"`
	Status     string  `json:"status"`
	Message    *string `json:"message"`
	IsIncoming bool    `json:"is_incoming"`
}

type friendInfo struct {
	ID   string `json:"id"`
	User struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
}

type ensureChatResponse struct {
	RoomID   string `json:"room_id"`
	RoomName string `json:"room_name"`
	RoomType string `json:"room_type"`
	FriendID string `json:"friend_id"`
}

func createFriendRequest(t *testing.T, c *testutil.Client, token, targetUserID string) friendRequestInfo {
	t.Helper()
	payload := map[string]any{
		"target_user_id": targetUserID,
		"message":        "go-test",
	}
	resp, body, err := c.DoJSON("POST", "/friends/requests", payload, token)
	if err != nil {
		t.Fatalf("create friend request http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("create friend request status=%d body=%s", resp.StatusCode, string(body))
	}
	var info friendRequestInfo
	if err := testutil.DecodeJSON(body, &info); err != nil {
		t.Fatalf("create friend request decode: %v body=%s", err, string(body))
	}
	return info
}

func listFriendRequests(t *testing.T, c *testutil.Client, token, direction, status string) []friendRequestInfo {
	t.Helper()
	path := "/friends/requests"
	q := url.Values{}
	if direction != "" {
		q.Set("direction", direction)
	}
	if status != "" {
		q.Set("status", status)
	}
	if len(q) > 0 {
		path += "?" + q.Encode()
	}
	resp, body, err := c.DoJSON("GET", path, nil, token)
	if err != nil {
		t.Fatalf("list friend requests http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list friend requests status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []friendRequestInfo
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list friend requests decode: %v body=%s", err, string(body))
	}
	return items
}

func respondFriendRequest(t *testing.T, c *testutil.Client, token, requestID, action string) friendRequestInfo {
	t.Helper()
	payload := map[string]any{
		"action": action,
	}
	resp, body, err := c.DoJSON("POST", "/friends/requests/"+requestID+"/respond", payload, token)
	if err != nil {
		t.Fatalf("respond friend request http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("respond friend request status=%d body=%s", resp.StatusCode, string(body))
	}
	var info friendRequestInfo
	if err := testutil.DecodeJSON(body, &info); err != nil {
		t.Fatalf("respond friend request decode: %v body=%s", err, string(body))
	}
	return info
}

func listFriends(t *testing.T, c *testutil.Client, token string) []friendInfo {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/friends", nil, token)
	if err != nil {
		t.Fatalf("list friends http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list friends status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []friendInfo
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list friends decode: %v body=%s", err, string(body))
	}
	return items
}

func ensurePrivateChat(t *testing.T, c *testutil.Client, token, friendUserID string) ensureChatResponse {
	t.Helper()
	resp, body, err := c.DoJSON("POST", "/friends/"+friendUserID+"/chat", map[string]any{}, token)
	if err != nil {
		t.Fatalf("ensure private chat http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("ensure private chat status=%d body=%s", resp.StatusCode, string(body))
	}
	var out ensureChatResponse
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("ensure private chat decode: %v body=%s", err, string(body))
	}
	return out
}

func TestFriendRequest_Accept_CreatesFriendshipAndPrivateChat(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	loginA := testutil.Login(t, c, userA.Username, pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	req := createFriendRequest(t, c, loginA.Token, userB.ID)
	if req.Status != "pending" {
		t.Fatalf("expected status=pending, got %q", req.Status)
	}
	if req.IsIncoming {
		t.Fatalf("expected requester view is_incoming=false, got true")
	}

	incoming := listFriendRequests(t, c, loginB.Token, "incoming", "pending")
	if !slices.ContainsFunc(incoming, func(r friendRequestInfo) bool { return r.ID == req.ID && r.IsIncoming }) {
		t.Fatalf("expected incoming pending request in list, got %+v", incoming)
	}

	accepted := respondFriendRequest(t, c, loginB.Token, req.ID, "accept")
	if accepted.Status != "accepted" {
		t.Fatalf("expected status=accepted, got %q", accepted.Status)
	}

	// 最终好友列表应互相可见
	friendsA := listFriends(t, c, loginA.Token)
	if !slices.ContainsFunc(friendsA, func(f friendInfo) bool { return f.User.ID == userB.ID }) {
		t.Fatalf("expected userB in friendsA, got %+v", friendsA)
	}
	friendsB := listFriends(t, c, loginB.Token)
	if !slices.ContainsFunc(friendsB, func(f friendInfo) bool { return f.User.ID == userA.ID }) {
		t.Fatalf("expected userA in friendsB, got %+v", friendsB)
	}

	// 私聊房间可确保创建
	chatA := ensurePrivateChat(t, c, loginA.Token, userB.ID)
	if chatA.RoomID == "" || chatA.FriendID != userB.ID {
		t.Fatalf("unexpected ensure chat response: %+v", chatA)
	}
	chatB := ensurePrivateChat(t, c, loginB.Token, userA.ID)
	if chatB.RoomID == "" || chatB.FriendID != userA.ID {
		t.Fatalf("unexpected ensure chat response: %+v", chatB)
	}
	if chatA.RoomID != chatB.RoomID {
		t.Fatalf("expected same private room id, got A=%s B=%s", chatA.RoomID, chatB.RoomID)
	}

	// 友链创建后，重复 ensure_chat 应稳定返回（非严格断言，只做一次轻量等待避免极端并发）
	time.Sleep(10 * time.Millisecond)
	chatA2 := ensurePrivateChat(t, c, loginA.Token, userB.ID)
	if chatA2.RoomID != chatA.RoomID {
		t.Fatalf("expected stable room id, got %s vs %s", chatA.RoomID, chatA2.RoomID)
	}
}
