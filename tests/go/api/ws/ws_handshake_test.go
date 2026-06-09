package ws_test

import (
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestWebSocketHandshake_InvalidToken_Unauthorized(t *testing.T) {
	c := testutil.NewClient()
	url := strings.Replace(c.BaseURL, "http://", "ws://", 1) + "/ws?token=invalid-token"
	url = strings.Replace(url, "ws://", "http://", 1)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("build request failed: %v", err)
	}
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Sec-WebSocket-Version", "13")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("ws handshake request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expect 401 for invalid ws token, got %d", resp.StatusCode)
	}
}
