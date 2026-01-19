package system_test

import (
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestReadyz_Success(t *testing.T) {
	c := testutil.NewClient()

	resp, body, err := c.DoJSON("GET", "/readyz", nil, "")
	if err != nil {
		t.Fatalf("readyz http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("readyz status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Status string `json:"status"`
		Checks struct {
			Database struct {
				Status string `json:"status"`
			} `json:"database"`
			RedisSession struct {
				Status string `json:"status"`
			} `json:"redisSession"`
			RedisCache struct {
				Status string `json:"status"`
			} `json:"redisCache"`
		} `json:"checks"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode response: %v body=%s", err, string(body))
	}
	if result.Status != "ok" {
		t.Fatalf("expected status=ok, got %s", result.Status)
	}
	if result.Checks.Database.Status != "ok" {
		t.Fatalf("expected database.status=ok, got %s", result.Checks.Database.Status)
	}
}

func TestHealthz_Success(t *testing.T) {
	c := testutil.NewClient()

	resp, body, err := c.DoJSON("GET", "/healthz", nil, "")
	if err != nil {
		t.Fatalf("healthz http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("healthz status=%d body=%s", resp.StatusCode, string(body))
	}
	// /healthz 返回纯文本 "ok"
	if string(body) != "ok" {
		t.Fatalf("expected body='ok', got '%s'", string(body))
	}
}

func TestRootPath(t *testing.T) {
	c := testutil.NewClient()

	resp, _, err := c.DoJSON("GET", "/", nil, "")
	if err != nil {
		t.Fatalf("root path http error: %v", err)
	}
	// 根路径应该返回成功（可能是 200 或 404，取决于实现）
	if resp.StatusCode >= 500 {
		t.Fatalf("root path returned server error: %d", resp.StatusCode)
	}
}
