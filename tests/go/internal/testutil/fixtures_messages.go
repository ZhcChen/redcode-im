package testutil

import "testing"

type sendMessageResponse struct {
	Message struct {
		ID string `json:"id"`
	} `json:"message"`
}

func SendMessage(t *testing.T, c *Client, token, roomID, content string) string {
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
	var sm sendMessageResponse
	if err := DecodeJSON(body, &sm); err != nil {
		t.Fatalf("send message decode: %v body=%s", err, string(body))
	}
	if sm.Message.ID == "" {
		t.Fatalf("send message missing id: body=%s", string(body))
	}
	return sm.Message.ID
}
