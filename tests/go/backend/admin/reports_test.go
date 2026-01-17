package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminReportsResponse struct {
	Reports  []any `json:"reports"`
	Total    int64 `json:"total"`
	Page     int64 `json:"page"`
	PageSize int64 `json:"pageSize"`
}

func TestAdmin_Reports_List(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin reports test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// list_reports_admin 会依赖默认存储提供商（用于生成附件下载 URL）
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	resp, body, err := c.DoJSON("GET", "/api/admin/reports?page=1&page_size=20", nil, admin.Token)
	if err != nil {
		t.Fatalf("list reports http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list reports status=%d body=%s", resp.StatusCode, string(body))
	}
	var out adminReportsResponse
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode list reports: %v body=%s", err, string(body))
	}
	if out.Page != 1 || out.PageSize != 20 {
		t.Fatalf("unexpected paging: page=%d pageSize=%d body=%s", out.Page, out.PageSize, string(body))
	}
	if out.Total < 0 {
		t.Fatalf("expected total>=0, got %d body=%s", out.Total, string(body))
	}

	// invalid targetType => 400
	respBad, bodyBad, err := c.DoJSON("GET", "/api/admin/reports?targetType=bad", nil, admin.Token)
	if err != nil {
		t.Fatalf("list reports (bad targetType) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected list reports (bad targetType) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}
}
