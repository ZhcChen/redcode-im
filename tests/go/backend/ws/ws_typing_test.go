package ws_test

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"redcode-im-tests/internal/testutil"
)

func startJSONEventPump(t *testing.T, conn *websocket.Conn) <-chan map[string]any {
	t.Helper()
	ch := make(chan map[string]any, 32)
	go func() {
		defer close(ch)
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}
			var m map[string]any
			if err := json.Unmarshal(data, &m); err != nil {
				continue
			}
			ch <- m
		}
	}()
	return ch
}

func waitForTypeFromChan(t *testing.T, ch <-chan map[string]any, want string, timeout time.Duration) map[string]any {
	t.Helper()
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	for {
		select {
		case ev, ok := <-ch:
			if !ok {
				t.Fatalf("ws closed while waiting for type=%q", want)
			}
			if typ, _ := ev["type"].(string); typ == want {
				return ev
			}
		case <-timer.C:
			t.Fatalf("timeout waiting for ws type=%q", want)
		}
	}
}

func assertNoTypeFromChan(t *testing.T, ch <-chan map[string]any, forbidden string, timeout time.Duration) {
	t.Helper()
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	for {
		select {
		case ev, ok := <-ch:
			if !ok {
				t.Fatalf("ws closed while expecting no type=%q", forbidden)
			}
			if typ, _ := ev["type"].(string); typ == forbidden {
				t.Fatalf("unexpected ws type=%q payload=%v", forbidden, ev)
			}
		case <-timer.C:
			return
		}
	}
}

func TestWebSocket_TypingRequiresJoin(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	wsURL := wsURLFromBase(t, c.BaseURL)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = conn.Close() })

	if err := conn.WriteJSON(map[string]any{"type": "auth", "token": login.Token}); err != nil {
		t.Fatalf("ws write auth: %v", err)
	}
	_ = waitForType(t, conn, "authed", 5*time.Second)

	// 未 join 房间直接 typing，必须 error
	if err := conn.WriteJSON(map[string]any{
		"type":      "typing",
		"room_id":   "00000000-0000-0000-0000-000000000000",
		"is_typing": true,
	}); err != nil {
		t.Fatalf("ws write typing: %v", err)
	}
	_ = waitForType(t, conn, "error", 5*time.Second)
}

func TestWebSocket_TypingThrottle(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-ws-typing-"+time.Now().Format("150405"), []string{user2.ID})

	wsURL := wsURLFromBase(t, c.BaseURL)
	sender, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = sender.Close() })

	observer, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("ws dial error: %v url=%s", err, wsURL)
	}
	t.Cleanup(func() { _ = observer.Close() })

	// sender auth + join
	if err := sender.WriteJSON(map[string]any{"type": "auth", "token": login1.Token}); err != nil {
		t.Fatalf("ws write auth(sender): %v", err)
	}
	_ = waitForType(t, sender, "authed", 5*time.Second)

	if err := sender.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join(sender): %v", err)
	}
	_ = waitForType(t, sender, "joined", 5*time.Second)

	// observer auth + join
	if err := observer.WriteJSON(map[string]any{"type": "auth", "token": login2.Token}); err != nil {
		t.Fatalf("ws write auth(observer): %v", err)
	}
	_ = waitForType(t, observer, "authed", 5*time.Second)

	if err := observer.WriteJSON(map[string]any{"type": "join", "room_id": roomID}); err != nil {
		t.Fatalf("ws write join(observer): %v", err)
	}
	_ = waitForType(t, observer, "joined", 5*time.Second)

	events := startJSONEventPump(t, observer)

	// 1) sender typing=true -> observer should get typing_update
	if err := sender.WriteJSON(map[string]any{"type": "typing", "room_id": roomID, "is_typing": true}); err != nil {
		t.Fatalf("ws write typing true(sender): %v", err)
	}
	ev1 := waitForTypeFromChan(t, events, "typing_update", 5*time.Second)
	if gotRoom, _ := ev1["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected typing_update room_id: %v", ev1)
	}
	if gotUser, _ := ev1["user_id"].(string); gotUser != user1.ID {
		t.Fatalf("unexpected typing_update user_id: %v", ev1)
	}
	if got, ok := ev1["is_typing"].(bool); !ok || !got {
		t.Fatalf("expected is_typing=true, got %v", ev1)
	}

	// 2) 短时间内重复 typing=true 应被节流，不应再次推送 typing_update
	if err := sender.WriteJSON(map[string]any{"type": "typing", "room_id": roomID, "is_typing": true}); err != nil {
		t.Fatalf("ws write typing true again(sender): %v", err)
	}
	assertNoTypeFromChan(t, events, "typing_update", 900*time.Millisecond)

	// 3) 超过节流窗口后，typing=true 可再次推送
	time.Sleep(1300 * time.Millisecond)
	if err := sender.WriteJSON(map[string]any{"type": "typing", "room_id": roomID, "is_typing": true}); err != nil {
		t.Fatalf("ws write typing true after throttle(sender): %v", err)
	}
	_ = waitForTypeFromChan(t, events, "typing_update", 5*time.Second)

	// 4) 状态变化 typing=false 允许立即推送
	if err := sender.WriteJSON(map[string]any{"type": "typing", "room_id": roomID, "is_typing": false}); err != nil {
		t.Fatalf("ws write typing false(sender): %v", err)
	}
	ev2 := waitForTypeFromChan(t, events, "typing_update", 5*time.Second)
	if gotRoom, _ := ev2["room_id"].(string); gotRoom != roomID {
		t.Fatalf("unexpected typing_update room_id: %v", ev2)
	}
	if gotUser, _ := ev2["user_id"].(string); gotUser != user1.ID {
		t.Fatalf("unexpected typing_update user_id: %v", ev2)
	}
	if got, ok := ev2["is_typing"].(bool); !ok || got {
		t.Fatalf("expected is_typing=false, got %v", ev2)
	}
}
