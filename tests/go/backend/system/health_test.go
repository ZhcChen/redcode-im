package system_test

import (
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestHealthz_OK(t *testing.T) {
	c := testutil.NewClient()
	resp, err := c.HTTP.Get(c.BaseURL + "/healthz")
	if err != nil {
		t.Fatalf("healthz request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect 200, got %d", resp.StatusCode)
	}
}
