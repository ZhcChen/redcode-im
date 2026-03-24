package ws

import (
	"context"
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
