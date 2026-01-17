package messages_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type unreadCount struct {
	RoomID           string  `json:"room_id"`
	UnreadCount      int64   `json:"unread_count"`
	LastReadMessageID *string `json:"last_read_message_id"`
	LastReadAt       *string `json:"last_read_at"`
}

type messageReadInfo struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	ReadAt   string `json:"read_at"`
}

func getUnreadCount(t *testing.T, c *testutil.Client, token, roomID string) unreadCount {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/unread_count", nil, token)
	if err != nil {
		t.Fatalf("get unread_count http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get unread_count status=%d body=%s", resp.StatusCode, string(body))
	}
	var out unreadCount
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode unread_count: %v body=%s", err, string(body))
	}
	return out
}

func getAllUnreadCounts(t *testing.T, c *testutil.Client, token string) []unreadCount {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/unread_counts", nil, token)
	if err != nil {
		t.Fatalf("get all unread_counts http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get all unread_counts status=%d body=%s", resp.StatusCode, string(body))
	}
	var out []unreadCount
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode all unread_counts: %v body=%s", err, string(body))
	}
	return out
}

func markMessageRead(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	payload := map[string]any{
		"message_id": messageID,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/read", payload, token)
	if err != nil {
		t.Fatalf("mark read http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("mark read status=%d body=%s", resp.StatusCode, string(body))
	}
}

func getMessageReadList(t *testing.T, c *testutil.Client, token, roomID, messageID string) []messageReadInfo {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/messages/"+messageID+"/reads", nil, token)
	if err != nil {
		t.Fatalf("get message reads http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get message reads status=%d body=%s", resp.StatusCode, string(body))
	}
	var out []messageReadInfo
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode message reads: %v body=%s", err, string(body))
	}
	return out
}

func TestMessageReadAndUnreadCounts_Flow(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-read-"+time.Now().Format("150405"), []string{user2.ID})

	// user1 发送消息，user2 未读数应增加（sender 自己未读数应为 0）
	msgID := testutil.SendMessage(t, c, login1.Token, roomID, "read_"+time.Now().Format("20060102150405.000000000"))

	u1Unread := getUnreadCount(t, c, login1.Token, roomID)
	if u1Unread.UnreadCount != 0 {
		t.Fatalf("expected sender unread_count=0, got %+v", u1Unread)
	}

	u2Unread := getUnreadCount(t, c, login2.Token, roomID)
	if u2Unread.UnreadCount != 1 {
		t.Fatalf("expected receiver unread_count=1, got %+v", u2Unread)
	}

	all := getAllUnreadCounts(t, c, login2.Token)
	if !slices.ContainsFunc(all, func(item unreadCount) bool {
		return item.RoomID == roomID && item.UnreadCount == 1
	}) {
		t.Fatalf("expected unread_counts include room=%s count=1, got %+v", roomID, all)
	}

	// 标记已读后，未读数应回到 0，并写入 last_read_message_id
	markMessageRead(t, c, login2.Token, roomID, msgID)
	u2Unread2 := getUnreadCount(t, c, login2.Token, roomID)
	if u2Unread2.UnreadCount != 0 {
		t.Fatalf("expected unread_count=0 after read, got %+v", u2Unread2)
	}
	if u2Unread2.LastReadMessageID == nil || *u2Unread2.LastReadMessageID != msgID {
		t.Fatalf("expected last_read_message_id=%s, got %+v", msgID, u2Unread2)
	}

	reads := getMessageReadList(t, c, login1.Token, roomID, msgID)
	if !slices.ContainsFunc(reads, func(r messageReadInfo) bool { return r.UserID == user2.ID }) {
		t.Fatalf("expected reads include user2=%s, got %+v", user2.ID, reads)
	}
}

