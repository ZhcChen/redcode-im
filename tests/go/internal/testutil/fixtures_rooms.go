package testutil

import "testing"

type CreateRoomResponse struct {
	Room struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"room"`
}

func CreateGroupRoom(t *testing.T, c *Client, token string, name string, memberIDs []string) string {
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
	var rr CreateRoomResponse
	if err := DecodeJSON(body, &rr); err != nil {
		t.Fatalf("create group decode: %v body=%s", err, string(body))
	}
	return rr.Room.ID
}

func CreatePublicRoom(t *testing.T, c *Client, token string, name string) string {
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
	var rr CreateRoomResponse
	if err := DecodeJSON(body, &rr); err != nil {
		t.Fatalf("create public room decode: %v body=%s", err, string(body))
	}
	return rr.Room.ID
}
