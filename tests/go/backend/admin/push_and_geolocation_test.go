package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type pushLogsResponse struct {
	Logs []struct {
		ID string `json:"id"`
	} `json:"logs"`
	Total  int64 `json:"total"`
	Limit  int64 `json:"limit"`
	Offset int64 `json:"offset"`
}

type pushLogCleanupResponse struct {
	Success      bool   `json:"success"`
	DeletedCount uint64 `json:"deletedCount"`
	Message      string `json:"message"`
}

type pushJobQueueStatsResponse struct {
	Pending         int64   `json:"pending"`
	Retry           int64   `json:"retry"`
	Done            int64   `json:"done"`
	Failed          int64   `json:"failed"`
	Due             int64   `json:"due"`
	NextRunAt       *string `json:"nextRunAt"`
	OldestCreatedAt *string `json:"oldestCreatedAt"`
}

type ipGeolocationStatusResponse struct {
	Enabled     bool   `json:"enabled"`
	Description string `json:"description"`
}

func TestAdmin_PushLogs_ListAndCleanup(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push logs test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respList, bodyList, err := c.DoJSON("GET", "/api/admin/push/logs?limit=5&offset=0", nil, admin.Token)
	if err != nil {
		t.Fatalf("list push logs http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list push logs status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var logs pushLogsResponse
	if err := testutil.DecodeJSON(bodyList, &logs); err != nil {
		t.Fatalf("decode push logs: %v body=%s", err, string(bodyList))
	}
	if logs.Limit <= 0 {
		t.Fatalf("expected limit > 0, got %d body=%s", logs.Limit, string(bodyList))
	}
	if logs.Offset < 0 || logs.Total < 0 {
		t.Fatalf("expected offset/total >=0, got offset=%d total=%d body=%s", logs.Offset, logs.Total, string(bodyList))
	}

	// cleanup: retentionDays 必须 >0（camelCase）
	respBad, bodyBad, err := c.DoJSON("POST", "/api/admin/push/logs/cleanup", map[string]any{
		"retentionDays": 0,
	}, admin.Token)
	if err != nil {
		t.Fatalf("cleanup push logs (bad) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected cleanup push logs (bad) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}

	// 用一个很大的保留天数，避免与其它测试产生删除竞争
	respOK, bodyOK, err := c.DoJSON("POST", "/api/admin/push/logs/cleanup", map[string]any{
		"retentionDays": 3650,
	}, admin.Token)
	if err != nil {
		t.Fatalf("cleanup push logs http error: %v", err)
	}
	if respOK.StatusCode != 200 {
		t.Fatalf("cleanup push logs status=%d body=%s", respOK.StatusCode, string(bodyOK))
	}
	var cleaned pushLogCleanupResponse
	if err := testutil.DecodeJSON(bodyOK, &cleaned); err != nil {
		t.Fatalf("decode cleanup push logs: %v body=%s", err, string(bodyOK))
	}
	if !cleaned.Success || cleaned.Message == "" {
		t.Fatalf("unexpected cleanup resp: %+v body=%s", cleaned, string(bodyOK))
	}
}

func TestAdmin_PushJobQueueStats(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push job queue stats test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/push/job-queue/stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("get push job queue stats http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get push job queue stats status=%d body=%s", resp.StatusCode, string(body))
	}
	var out pushJobQueueStatsResponse
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode push job queue stats: %v body=%s", err, string(body))
	}
	if out.Pending < 0 || out.Retry < 0 || out.Done < 0 || out.Failed < 0 || out.Due < 0 {
		t.Fatalf("expected counts >=0, got %+v body=%s", out, string(body))
	}
}

func TestAdmin_IpGeolocationEnabled_Toggle(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin ip geolocation toggle test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp0, body0, err := c.DoJSON("GET", "/api/admin/ip-geolocation/enabled", nil, admin.Token)
	if err != nil {
		t.Fatalf("get ip geolocation enabled http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("get ip geolocation enabled status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var original ipGeolocationStatusResponse
	if err := testutil.DecodeJSON(body0, &original); err != nil {
		t.Fatalf("decode ip geolocation enabled: %v body=%s", err, string(body0))
	}
	if original.Description == "" {
		t.Fatalf("expected description non-empty, body=%s", string(body0))
	}

	t.Cleanup(func() {
		_, _, _ = c.DoJSON("PATCH", "/api/admin/ip-geolocation/enabled", map[string]any{
			"enabled": original.Enabled,
		}, admin.Token)
	})

	resp1, body1, err := c.DoJSON("PATCH", "/api/admin/ip-geolocation/enabled", map[string]any{
		"enabled": !original.Enabled,
	}, admin.Token)
	if err != nil {
		t.Fatalf("set ip geolocation enabled http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("set ip geolocation enabled status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var updated ipGeolocationStatusResponse
	if err := testutil.DecodeJSON(body1, &updated); err != nil {
		t.Fatalf("decode set ip geolocation enabled: %v body=%s", err, string(body1))
	}
	if updated.Enabled == original.Enabled {
		t.Fatalf("expected enabled toggled, original=%v updated=%v body=%s", original.Enabled, updated.Enabled, string(body1))
	}
}

