package ws_test

import (
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestWebSocket_HTTPGetWithoutUpgrade(t *testing.T) {
	c := testutil.NewClient()
	resp, body, err := c.DoJSON("GET", "/ws", nil, "")
	if err != nil {
		t.Fatalf("get /ws http error: %v", err)
	}
	if resp.StatusCode != 400 && resp.StatusCode != 426 {
		t.Fatalf("expected /ws status=400/426 without upgrade, got %d body=%s", resp.StatusCode, string(body))
	}
}
