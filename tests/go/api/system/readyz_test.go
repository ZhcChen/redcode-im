package system_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type readyzComponent struct {
	Status    string  `json:"status"`
	LatencyMs *uint64 `json:"latencyMs"`
	Error     *string `json:"error"`
}

type readyzResponse struct {
	Status string `json:"status"`
	Checks struct {
		Database     readyzComponent `json:"database"`
		RedisSession readyzComponent `json:"redisSession"`
		RedisCache   readyzComponent `json:"redisCache"`
	} `json:"checks"`
}

func TestReadyz_OK(t *testing.T) {
	c := testutil.NewClient()

	resp, err := c.HTTP.Get(c.BaseURL + "/readyz")
	if err != nil {
		t.Fatalf("readyz request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("readyz expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload readyzResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode readyz response failed: %v", err)
	}

	if payload.Status != "ok" {
		t.Fatalf("readyz status expect ok, got %q", payload.Status)
	}

	assertComponentHealthy(t, "database", payload.Checks.Database)
	assertComponentHealthy(t, "redisSession", payload.Checks.RedisSession)
	assertComponentHealthy(t, "redisCache", payload.Checks.RedisCache)
}

func assertComponentHealthy(t *testing.T, name string, c readyzComponent) {
	t.Helper()
	if c.Status != "ok" {
		t.Fatalf("%s status expect ok, got %q (error=%v)", name, c.Status, c.Error)
	}
	if c.LatencyMs == nil {
		t.Fatalf("%s latencyMs is nil", name)
	}
	if c.Error != nil {
		t.Fatalf("%s error expect nil, got %q", name, *c.Error)
	}
}
