package ws_test

import (
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func TestWebSocket_PingPong_WithoutAuth(t *testing.T) {
	c := testutil.NewClient()

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{"type": "ping"}); err != nil {
		t.Fatalf("ws write ping: %v", err)
	}
	_ = waitForType(t, conn, "pong", 5*time.Second)
}

func TestWebSocket_JoinWithoutAuth_ReturnsError(t *testing.T) {
	c := testutil.NewClient()

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{
		"type":    "join",
		"room_id": "00000000-0000-0000-0000-000000000000",
	}); err != nil {
		t.Fatalf("ws write join: %v", err)
	}
	ev := waitForType(t, conn, "error", 5*time.Second)
	if msg, _ := ev["message"].(string); msg == "" {
		t.Fatalf("expected non-empty error message: %v", ev)
	}
}

func TestWebSocket_TypingWithoutAuth_ReturnsError(t *testing.T) {
	c := testutil.NewClient()

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{
		"type":      "typing",
		"room_id":   "00000000-0000-0000-0000-000000000000",
		"is_typing": true,
	}); err != nil {
		t.Fatalf("ws write typing: %v", err)
	}
	ev := waitForType(t, conn, "error", 5*time.Second)
	if msg, _ := ev["message"].(string); msg == "" {
		t.Fatalf("expected non-empty error message: %v", ev)
	}
}

func TestWebSocket_JoinNonMember_ReturnsError(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	outsider := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	outsiderLogin := testutil.Login(t, c, outsider.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-ws-nm-"+time.Now().Format("150405"), []string{member.ID})

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{"type": "auth", "token": outsiderLogin.Token}); err != nil {
		t.Fatalf("ws write auth: %v", err)
	}
	_ = waitForType(t, conn, "authed", 5*time.Second)

	if err := conn.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join: %v", err)
	}
	ev := waitForType(t, conn, "error", 8*time.Second)
	if msg, _ := ev["message"].(string); msg == "" {
		t.Fatalf("expected non-empty error message: %v", ev)
	}
}
