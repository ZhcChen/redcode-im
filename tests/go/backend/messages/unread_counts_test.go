package messages_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type unreadCountResponse struct {
	RoomID            string  `json:"room_id"`
	UnreadCount       int64   `json:"unread_count"`
	LastReadMessageID *string `json:"last_read_message_id"`
	LastReadAt        *string `json:"last_read_at"`
}

func TestUnreadCounts_MultiMessageReadUntil_OK(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("ucnta")
	userB := testutil.UniqueUsername("ucntb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)

	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "unread-room")

	_ = sendTextMessage(t, c, loginA.Token, room.ID, "hello-1")
	lastMessageID := sendTextMessage(t, c, loginA.Token, room.ID, "hello-2")

	beforeRead := fetchUnreadCountForRoom(t, c, loginB.Token, room.ID)
	if beforeRead.UnreadCount != 2 {
		t.Fatalf("unread count before read expect 2, got %d", beforeRead.UnreadCount)
	}

	markReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages/read_until", loginB.Token, map[string]any{
		"message_id": lastMessageID,
	})
	markResp, err := c.HTTP.Do(markReq)
	if err != nil {
		t.Fatalf("mark read until failed: %v", err)
	}
	defer markResp.Body.Close()
	if markResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(markResp.Body)
		t.Fatalf("mark read until expect 200, got %d: %s", markResp.StatusCode, string(body))
	}

	afterRead := fetchUnreadCountForRoom(t, c, loginB.Token, room.ID)
	if afterRead.UnreadCount != 0 {
		t.Fatalf("unread count after read expect 0, got %d", afterRead.UnreadCount)
	}

	roomUnreadReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/rooms/"+room.ID+"/unread_count", loginB.Token, nil)
	roomUnreadResp, err := c.HTTP.Do(roomUnreadReq)
	if err != nil {
		t.Fatalf("get room unread_count failed: %v", err)
	}
	defer roomUnreadResp.Body.Close()
	if roomUnreadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(roomUnreadResp.Body)
		t.Fatalf("room unread_count expect 200, got %d: %s", roomUnreadResp.StatusCode, string(body))
	}
	var roomUnread unreadCountResponse
	if err := json.NewDecoder(roomUnreadResp.Body).Decode(&roomUnread); err != nil {
		t.Fatalf("decode room unread_count failed: %v", err)
	}
	if roomUnread.UnreadCount != 0 {
		t.Fatalf("room unread_count after read expect 0, got %d", roomUnread.UnreadCount)
	}
}

func sendTextMessage(t *testing.T, c *testutil.Client, token, roomID, content string) string {
	t.Helper()
	req := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+roomID+"/messages", token, map[string]any{
		"content": content,
	})
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("send message failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("send message expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload struct {
		Message struct {
			ID string `json:"id"`
		} `json:"message"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode send message response failed: %v", err)
	}
	if payload.Message.ID == "" {
		t.Fatalf("send message response id is empty")
	}
	return payload.Message.ID
}

func fetchUnreadCountForRoom(t *testing.T, c *testutil.Client, token, roomID string) unreadCountResponse {
	t.Helper()
	unreadReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/unread_counts", token, nil)
	unreadResp, err := c.HTTP.Do(unreadReq)
	if err != nil {
		t.Fatalf("get unread_counts failed: %v", err)
	}
	defer unreadResp.Body.Close()
	if unreadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(unreadResp.Body)
		t.Fatalf("unread_counts expect 200, got %d: %s", unreadResp.StatusCode, string(body))
	}
	var rows []unreadCountResponse
	if err := json.NewDecoder(unreadResp.Body).Decode(&rows); err != nil {
		t.Fatalf("decode unread_counts failed: %v", err)
	}
	for _, row := range rows {
		if row.RoomID == roomID {
			return row
		}
	}
	t.Fatalf("room %s not found in unread_counts: %+v", roomID, rows)
	return unreadCountResponse{}
}
