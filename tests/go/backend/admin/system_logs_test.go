package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type systemLogsResponse struct {
	Logs []struct {
		ID        string `json:"id"`
		Level     string `json:"level"`
		Target    string `json:"target"`
		Message   string `json:"message"`
		NodeID    string `json:"nodeId"`
		CreatedAt string `json:"createdAt"`
	} `json:"logs"`
	Total  int64 `json:"total"`
	Limit  int64 `json:"limit"`
	Offset int64 `json:"offset"`
}

type systemLogStatsResponse struct {
	TotalCount int64   `json:"totalCount"`
	DebugCount int64   `json:"debugCount"`
	InfoCount  int64   `json:"infoCount"`
	WarnCount  int64   `json:"warnCount"`
	ErrorCount int64   `json:"errorCount"`
	OldestLog  *string `json:"oldestLog"`
	NewestLog  *string `json:"newestLog"`
}

func TestAdmin_SystemLogs_StatsAndQuery(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin system logs test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respList, bodyList, err := c.DoJSON("GET", "/api/admin/logs?limit=5&offset=0", nil, admin.Token)
	if err != nil {
		t.Fatalf("list logs http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list logs status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var logs systemLogsResponse
	if err := testutil.DecodeJSON(bodyList, &logs); err != nil {
		t.Fatalf("decode logs: %v body=%s", err, string(bodyList))
	}
	if logs.Limit <= 0 {
		t.Fatalf("expected limit > 0, got %d body=%s", logs.Limit, string(bodyList))
	}
	if logs.Offset < 0 || logs.Total < 0 {
		t.Fatalf("expected offset/total >=0, got offset=%d total=%d body=%s", logs.Offset, logs.Total, string(bodyList))
	}

	respStats, bodyStats, err := c.DoJSON("GET", "/api/admin/logs/stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("log stats http error: %v", err)
	}
	if respStats.StatusCode != 200 {
		t.Fatalf("log stats status=%d body=%s", respStats.StatusCode, string(bodyStats))
	}
	var stats systemLogStatsResponse
	if err := testutil.DecodeJSON(bodyStats, &stats); err != nil {
		t.Fatalf("decode log stats: %v body=%s", err, string(bodyStats))
	}
	if stats.TotalCount < 0 || stats.DebugCount < 0 || stats.InfoCount < 0 || stats.WarnCount < 0 || stats.ErrorCount < 0 {
		t.Fatalf("expected counts >=0, got %+v body=%s", stats, string(bodyStats))
	}

	// cleanup: retentionDays 必须 >0（camelCase）
	respBad, bodyBad, err := c.DoJSON("POST", "/api/admin/logs/cleanup", map[string]any{
		"retentionDays": 0,
	}, admin.Token)
	if err != nil {
		t.Fatalf("cleanup logs (bad) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected cleanup logs (bad) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}
}
