package ws_test

import (
	"encoding/json"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func wsURLFromBase(t *testing.T, base string) string {
	t.Helper()
	u, err := url.Parse(base)
	if err != nil {
		t.Fatalf("parse API_BASE_URL: %v", err)
	}
	switch strings.ToLower(u.Scheme) {
	case "http":
		u.Scheme = "ws"
	case "https":
		u.Scheme = "wss"
	default:
		t.Fatalf("unsupported API_BASE_URL scheme: %q", u.Scheme)
	}
	u.Path = "/ws"
	u.RawQuery = "format=json"
	return u.String()
}

func readJSONEvent(t *testing.T, conn *websocket.Conn, deadline time.Duration) map[string]any {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(deadline))
	_, data, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("ws read error: %v", err)
	}
	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("ws json decode: %v data=%s", err, string(data))
	}
	return m
}

func waitForType(t *testing.T, conn *websocket.Conn, want string, timeout time.Duration) map[string]any {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		ev := readJSONEvent(t, conn, time.Until(deadline))
		if typ, _ := ev["type"].(string); typ == want {
			return ev
		}
	}
	t.Fatalf("timeout waiting for ws type=%q", want)
	return nil
}

func TestWebSocket_AuthJoinAndMessagePush(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-ws-"+time.Now().Format("150405"), []string{user2.ID})

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	// 1) auth
	if err := conn.WriteJSON(map[string]any{"type": "auth", "token": login2.Token}); err != nil {
		t.Fatalf("ws write auth: %v", err)
	}
	_ = waitForType(t, conn, "authed", 5*time.Second)

	// 2) join room
	if err := conn.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join: %v", err)
	}
	_ = waitForType(t, conn, "joined", 5*time.Second)

	// 3) trigger push: send message by other member
	needle := "ws_push_" + time.Now().Format("20060102150405.000000000")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, needle)

	msg := waitForType(t, conn, "message", 8*time.Second)
	if gotRoom, _ := msg["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected room_id: %v", msg)
	}
	if gotContent, _ := msg["content"].(string); gotContent != needle {
		t.Fatalf("unexpected content: %v", msg)
	}
}
