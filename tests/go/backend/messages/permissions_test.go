package messages_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

func TestMessages_NonMember_ForbiddenOnRoomEndpoints(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	outsider := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	outsiderLogin := testutil.Login(t, c, outsider.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-perm-"+time.Now().Format("150405"), []string{member.ID})
	messageID := testutil.SendMessage(t, c, ownerLogin.Token, roomID, "perm_"+time.Now().Format("20060102150405.000000000"))

	// list messages
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/messages", nil, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider list messages http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for outsider list messages, got %d body=%s", resp.StatusCode, string(body))
	}

	// mark read
	resp, body, err = c.DoJSON("POST", "/rooms/"+roomID+"/messages/read", map[string]any{"message_id": messageID}, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider mark read http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for outsider mark read, got %d body=%s", resp.StatusCode, string(body))
	}

	// pin message
	resp, body, err = c.DoJSON("POST", "/rooms/"+roomID+"/messages/"+messageID+"/pin", map[string]any{}, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider pin http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for outsider pin, got %d body=%s", resp.StatusCode, string(body))
	}

	// unpin message
	resp, body, err = c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+messageID+"/pin", nil, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("outsider unpin http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for outsider unpin, got %d body=%s", resp.StatusCode, string(body))
	}
}
