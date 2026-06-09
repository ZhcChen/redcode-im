package system_test

import (
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestExternalMock_Healthz_OK(t *testing.T) {
	url := testutil.ExternalMockBaseURL() + "/healthz"
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("external mock healthz request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect 200 from external mock healthz, got %d", resp.StatusCode)
	}
}
