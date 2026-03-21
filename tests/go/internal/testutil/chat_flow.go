package testutil

import (
	"encoding/json"
	"io"
	"net/http"
)

type RoomInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	RoomType    string `json:"room_type"`
}

type CreateRoomResponse struct {
	Room RoomInfo `json:"room"`
}

func CreateGroupRoom(t TestingT, c *Client, ownerToken string, memberUserID string, name string) RoomInfo {
	t.Helper()

	payload := map[string]any{
		"name":        name,
		"description": "integration test room",
		"room_type":   "group",
		"member_ids":  []string{memberUserID},
	}
	req := NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms", ownerToken, payload)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create room request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("create room expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var result CreateRoomResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode create room response failed: %v", err)
	}
	if result.Room.ID == "" {
		t.Fatalf("room id is empty")
	}
	return result.Room
}
