package ws_test

import (
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func markMessageRead(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	payload := map[string]any{
		"message_id": messageID,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/read", payload, token)
	if err != nil {
		t.Fatalf("mark message read http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("mark message read status=%d body=%s", resp.StatusCode, string(body))
	}
}

func pinMessage(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/"+messageID+"/pin", map[string]any{}, token)
	if err != nil {
		t.Fatalf("pin message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("pin message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func unpinMessage(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	resp, body, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+messageID+"/pin", nil, token)
	if err != nil {
		t.Fatalf("unpin message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("unpin message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestWebSocket_MessageReadAndPinUpdate(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-ws-flow-"+time.Now().Format("150405"), []string{user2.ID})

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	// auth + join
	if err := conn.WriteJSON(map[string]any{"type": "auth", "token": login2.Token}); err != nil {
		t.Fatalf("ws write auth: %v", err)
	}
	_ = waitForType(t, conn, "authed", 5*time.Second)

	if err := conn.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join: %v", err)
	}
	_ = waitForType(t, conn, "joined", 5*time.Second)

	// 1) message push
	needle := "ws_flow_" + time.Now().Format("20060102150405.000000000")
	httpMessageID := testutil.SendMessage(t, c, login1.Token, roomID, needle)

	msg := waitForType(t, conn, "message", 8*time.Second)
	if gotRoom, _ := msg["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected room_id: %v", msg)
	}
	if gotContent, _ := msg["content"].(string); gotContent != needle {
		t.Fatalf("unexpected content: %v", msg)
	}
	if gotID, _ := msg["id"].(string); gotID != httpMessageID {
		t.Fatalf("unexpected message id: http=%s ws=%v", httpMessageID, msg)
	}

	// 2) HTTP read -> WS message_read
	markMessageRead(t, c, login2.Token, roomID, httpMessageID)
	readEv := waitForType(t, conn, "message_read", 8*time.Second)
	if gotRoom, _ := readEv["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected message_read room_id: %v", readEv)
	}
	if gotMessage, _ := readEv["message_id"].(string); gotMessage != httpMessageID {
		t.Fatalf("unexpected message_read message_id: %v", readEv)
	}
	if gotReader, _ := readEv["reader_id"].(string); gotReader != user2.ID {
		t.Fatalf("unexpected message_read reader_id: %v", readEv)
	}

	// 3) HTTP pin -> WS pin_update
	pinMessage(t, c, login1.Token, roomID, httpMessageID)
	pinEv := waitForType(t, conn, "pin_update", 8*time.Second)
	if gotRoom, _ := pinEv["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected pin_update room_id: %v", pinEv)
	}
	if gotMessage, _ := pinEv["message_id"].(string); gotMessage != httpMessageID {
		t.Fatalf("unexpected pin_update message_id: %v", pinEv)
	}
	if gotPinned, ok := pinEv["is_pinned"].(bool); !ok || !gotPinned {
		t.Fatalf("expected is_pinned=true, got %v", pinEv)
	}
	if gotBy, _ := pinEv["pinned_by"].(string); gotBy != user1.ID {
		t.Fatalf("unexpected pinned_by: %v", pinEv)
	}

	// 4) HTTP unpin -> WS pin_update (is_pinned=false)
	unpinMessage(t, c, login1.Token, roomID, httpMessageID)
	unpinEv := waitForType(t, conn, "pin_update", 8*time.Second)
	if gotRoom, _ := unpinEv["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected pin_update room_id: %v", unpinEv)
	}
	if gotMessage, _ := unpinEv["message_id"].(string); gotMessage != httpMessageID {
		t.Fatalf("unexpected pin_update message_id: %v", unpinEv)
	}
	if gotPinned, ok := unpinEv["is_pinned"].(bool); !ok || gotPinned {
		t.Fatalf("expected is_pinned=false, got %v", unpinEv)
	}
}
