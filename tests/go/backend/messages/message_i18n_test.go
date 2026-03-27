package messages_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type messageAPIErrorResponse struct {
	Code       int     `json:"code"`
	MessageKey string  `json:"message_key"`
	Message    string  `json:"message"`
	Details    *string `json:"details"`
}

func TestMessageClearRoomOwnerOnly_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("cleara")
	userB := testutil.UniqueUsername("clearb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "clear-i18n-room")

	req := testutil.NewAuthedJSONRequest(t, http.MethodDelete, c.BaseURL+"/rooms/"+room.ID+"/messages", loginB.Token, nil)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("clear room messages failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusForbidden {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("clear room expect 403, got %d: %s", resp.StatusCode, string(body))
	}

	var payload messageAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode clear room error response failed: %v", err)
	}

	if payload.Code != 40301 {
		t.Fatalf("unexpected error code: %d", payload.Code)
	}
	if payload.MessageKey != "message.clear_group_owner_only" {
		t.Fatalf("unexpected message_key: %s", payload.MessageKey)
	}
	if payload.Message != "Only the group owner can clear group chat history." {
		t.Fatalf("unexpected message: %s", payload.Message)
	}
	if payload.Details != nil {
		t.Fatalf("expected null details, got %q", *payload.Details)
	}
}
