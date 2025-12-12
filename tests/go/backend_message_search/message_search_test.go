package backend_message_search

import (
	"net/url"
	"strings"
	"testing"
	"time"
)

type roomResponse struct {
	Room struct {
		ID string `json:"id"`
	} `json:"room"`
}

type searchResponse struct {
	Results []struct {
		ID       string `json:"id"`
		RoomID   string `json:"room_id"`
		Content  string `json:"content"`
		RoomName string `json:"room_name"`
	} `json:"results"`
	Stats struct {
		TotalResults int64  `json:"total_results"`
		SearchTimeMs int64  `json:"search_time_ms"`
		Query        string `json:"query"`
	} `json:"stats"`
	HasMore bool `json:"has_more"`
}

func createGroup(t *testing.T, c *Client, token string, name string, memberIDs []string) string {
	t.Helper()
	payload := map[string]any{
		"name":        name,
		"description": "go-test",
		"member_ids":  memberIDs,
	}
	resp, body, err := c.DoJSON("POST", "/rooms", payload, token)
	if err != nil {
		t.Fatalf("create group http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("create group status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr roomResponse
	if err := Decode(body, &rr); err != nil {
		t.Fatalf("create group decode: %v body=%s", err, string(body))
	}
	return rr.Room.ID
}

func createPublicRoom(t *testing.T, c *Client, token string, name string) string {
	t.Helper()
	payload := map[string]any{
		"name":        name,
		"description": "go-test",
		"room_type":   "public",
		"member_ids":  []string{},
	}
	resp, body, err := c.DoJSON("POST", "/rooms", payload, token)
	if err != nil {
		t.Fatalf("create public room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("create public room status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr roomResponse
	if err := Decode(body, &rr); err != nil {
		t.Fatalf("create public room decode: %v body=%s", err, string(body))
	}
	return rr.Room.ID
}

func sendMessage(t *testing.T, c *Client, token, roomID, content string) {
	t.Helper()
	payload := map[string]any{
		"content": content,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", payload, token)
	if err != nil {
		t.Fatalf("send message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("send message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func searchMessages(t *testing.T, c *Client, token, query, roomID string) searchResponse {
	t.Helper()
	path := "/messages/search?query=" + url.QueryEscape(query)
	if roomID != "" {
		path += "&room_id=" + url.QueryEscape(roomID)
	}
	resp, body, err := c.DoJSON("GET", path, nil, token)
	if err != nil {
		t.Fatalf("search messages http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("search messages status=%d body=%s", resp.StatusCode, string(body))
	}
	var sr searchResponse
	if err := Decode(body, &sr); err != nil {
		t.Fatalf("search messages decode: %v body=%s", err, string(body))
	}
	return sr
}

func TestMessageSearch_OnlyReturnsAccessibleRooms(t *testing.T) {
	c := NewClient()
	pass := "Passw0rd!"

	user1 := registerUser(t, c, uniquePhone(), pass)
	user2 := registerUser(t, c, uniquePhone(), pass)

	login1 := login(t, c, user1.Username, pass)
	login2 := login(t, c, user2.Username, pass)

	sharedRoomID := createGroup(t, c, login1.Token, "go-search-shared-"+time.Now().Format("150405"), []string{user2.ID})
	privateRoomID := createPublicRoom(t, c, login1.Token, "go-search-private-"+time.Now().Format("150405"))

	needle := "needle_" + time.Now().Format("20060102150405.000000000")
	sharedContent := "shared " + needle
	privateContent := "private " + needle

	sendMessage(t, c, login1.Token, sharedRoomID, sharedContent)
	sendMessage(t, c, login1.Token, privateRoomID, privateContent)

	// user2 只能搜索到自己可见房间内的消息
	res := searchMessages(t, c, login2.Token, needle, "")
	if res.Stats.TotalResults != 1 || len(res.Results) != 1 {
		t.Fatalf("expected 1 result, got total=%d len=%d", res.Stats.TotalResults, len(res.Results))
	}
	if !strings.Contains(res.Results[0].Content, "shared") {
		t.Fatalf("unexpected content: %q", res.Results[0].Content)
	}

	// 指定 user2 不在的房间，必须返回空结果（不能越权）
	res2 := searchMessages(t, c, login2.Token, needle, privateRoomID)
	if res2.Stats.TotalResults != 0 || len(res2.Results) != 0 {
		t.Fatalf("expected 0 result for private room, got total=%d len=%d", res2.Stats.TotalResults, len(res2.Results))
	}
}

