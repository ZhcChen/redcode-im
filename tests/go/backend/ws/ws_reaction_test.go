package ws_test

import (
	"net/url"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func addReaction(t *testing.T, c *testutil.Client, token, roomID, messageID, reactionKey string) {
	t.Helper()
	payload := map[string]any{
		"reaction_key": reactionKey,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/"+messageID+"/reactions", payload, token)
	if err != nil {
		t.Fatalf("add reaction http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("add reaction status=%d body=%s", resp.StatusCode, string(body))
	}
}

func removeReaction(t *testing.T, c *testutil.Client, token, roomID, messageID, reactionKey string) {
	t.Helper()
	path := "/rooms/" + roomID + "/messages/" + messageID + "/reactions?reaction_key=" + url.QueryEscape(reactionKey)
	resp, body, err := c.DoJSON("DELETE", path, nil, token)
	if err != nil {
		t.Fatalf("remove reaction http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("remove reaction status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestWebSocket_ReactionUpdate_AddAndRemove(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-ws-react-"+time.Now().Format("150405"), []string{user2.ID})

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{"type": "auth", "token": login2.Token}); err != nil {
		t.Fatalf("ws write auth: %v", err)
	}
	_ = waitForType(t, conn, "authed", 5*time.Second)

	if err := conn.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join: %v", err)
	}
	_ = waitForType(t, conn, "joined", 5*time.Second)

	// send message by user1
	msgID := testutil.SendMessage(t, c, login1.Token, roomID, "react_"+time.Now().Format("20060102150405.000000000"))
	_ = waitForType(t, conn, "message", 8*time.Second)

	// add reaction by user2
	addReaction(t, c, login2.Token, roomID, msgID, "👍")
	ev1 := waitForType(t, conn, "reaction_update", 8*time.Second)
	if gotAction, _ := ev1["action"].(string); gotAction != "add" {
		t.Fatalf("expected action=add, got %v", ev1)
	}
	if gotKey, _ := ev1["reaction_key"].(string); gotKey != "👍" {
		t.Fatalf("unexpected reaction_key: %v", ev1)
	}
	if gotUser, _ := ev1["user_id"].(string); gotUser != user2.ID {
		t.Fatalf("unexpected user_id: %v", ev1)
	}

	// remove reaction by user2
	removeReaction(t, c, login2.Token, roomID, msgID, "👍")
	ev2 := waitForType(t, conn, "reaction_update", 8*time.Second)
	if gotAction, _ := ev2["action"].(string); gotAction != "remove" {
		t.Fatalf("expected action=remove, got %v", ev2)
	}
	if gotKey, _ := ev2["reaction_key"].(string); gotKey != "👍" {
		t.Fatalf("unexpected reaction_key: %v", ev2)
	}
	if gotUser, _ := ev2["user_id"].(string); gotUser != user2.ID {
		t.Fatalf("unexpected user_id: %v", ev2)
	}
}
