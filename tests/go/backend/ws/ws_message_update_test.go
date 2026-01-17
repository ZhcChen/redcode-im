package ws_test

import (
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func editMessage(t *testing.T, c *testutil.Client, token, roomID, messageID, newContent string) {
	t.Helper()
	payload := map[string]any{
		"content": newContent,
	}
	resp, body, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/messages/"+messageID, payload, token)
	if err != nil {
		t.Fatalf("edit message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("edit message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func deleteMessage(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	resp, body, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+messageID, nil, token)
	if err != nil {
		t.Fatalf("delete message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("delete message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestWebSocket_MessageEditedAndDeleted_EmitsMessageUpdate(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-ws-editdel-"+time.Now().Format("150405"), []string{user2.ID})

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

	// send message (user1)
	orig := "edit_me_" + time.Now().Format("20060102150405.000000000")
	msgID := testutil.SendMessage(t, c, login1.Token, roomID, orig)
	_ = waitForType(t, conn, "message", 8*time.Second)

	// edit message (user1) -> ws message_update (is_deleted=false)
	newContent := orig + "_edited"
	editMessage(t, c, login1.Token, roomID, msgID, newContent)
	upd1 := waitForType(t, conn, "message_update", 8*time.Second)
	if gotRoom, _ := upd1["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected message_update room_id: %v", upd1)
	}
	if gotMsg, _ := upd1["message_id"].(string); gotMsg != msgID {
		t.Fatalf("unexpected message_update message_id: %v", upd1)
	}
	if gotDeleted, ok := upd1["is_deleted"].(bool); !ok || gotDeleted {
		t.Fatalf("expected edit to emit is_deleted=false, got %v", upd1)
	}

	// delete message (user1) -> ws message_update (is_deleted=true)
	deleteMessage(t, c, login1.Token, roomID, msgID)
	upd2 := waitForType(t, conn, "message_update", 8*time.Second)
	if gotMsg, _ := upd2["message_id"].(string); gotMsg != msgID {
		t.Fatalf("unexpected message_update message_id: %v", upd2)
	}
	if gotDeleted, ok := upd2["is_deleted"].(bool); !ok || !gotDeleted {
		t.Fatalf("expected delete to emit is_deleted=true, got %v", upd2)
	}
}

