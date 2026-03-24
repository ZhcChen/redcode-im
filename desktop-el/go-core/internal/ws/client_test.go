package ws

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
)

func TestClientConnectAndDisconnect(t *testing.T) {
	upgrader := websocket.Upgrader{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.URL.Query().Get("token"); got != "access-token" {
			t.Fatalf("unexpected token query: %s", got)
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("upgrade failed: %v", err)
		}
		defer conn.Close()

		_, _, _ = conn.ReadMessage()
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	client := NewClient()
	if err := client.Connect(context.Background(), ConnectParams{
		URL:   wsURL,
		Token: "access-token",
	}); err != nil {
		t.Fatalf("connect failed: %v", err)
	}
	if got := client.Status(); got != StatusAuthenticated {
		t.Fatalf("unexpected status after connect: %s", got)
	}

	if err := client.Disconnect(); err != nil {
		t.Fatalf("disconnect failed: %v", err)
	}
	if got := client.Status(); got != StatusDisconnected {
		t.Fatalf("unexpected status after disconnect: %s", got)
	}
}

func TestClientReadMessageAfterConnect(t *testing.T) {
	upgrader := websocket.Upgrader{}
	done := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("upgrade failed: %v", err)
		}
		defer conn.Close()

		if err := conn.WriteJSON(map[string]any{
			"type":       "message",
			"room_id":    "room-2",
			"message_id": "msg-12",
			"content":    "来自 websocket 的消息",
		}); err != nil {
			t.Fatalf("write websocket payload failed: %v", err)
		}

		<-done
	}))
	defer func() {
		close(done)
		server.Close()
	}()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	client := NewClient()
	if err := client.Connect(context.Background(), ConnectParams{
		URL:   wsURL,
		Token: "access-token",
	}); err != nil {
		t.Fatalf("connect failed: %v", err)
	}
	defer func() {
		if err := client.Disconnect(); err != nil {
			t.Fatalf("disconnect failed: %v", err)
		}
	}()

	payload, err := client.ReadMessage(context.Background())
	if err != nil {
		t.Fatalf("read websocket payload failed: %v", err)
	}

	var message map[string]any
	if err := json.Unmarshal(payload, &message); err != nil {
		t.Fatalf("decode websocket payload failed: %v", err)
	}
	if message["type"] != "message" || message["message_id"] != "msg-12" {
		t.Fatalf("unexpected websocket payload: %+v", message)
	}
}
