package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 其他 Admin 接口测试

func TestAdmin_Settings_PrivacyPolicy(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/settings/privacy-policy", nil, admin.Token)
	if err != nil {
		t.Fatalf("get privacy policy http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get privacy policy status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_Settings_UserAgreement(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/settings/user-agreement", nil, admin.Token)
	if err != nil {
		t.Fatalf("get user agreement http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get user agreement status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_Users_GeolocationDistribution(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/users/geolocation/distribution", nil, admin.Token)
	if err != nil {
		t.Fatalf("get geolocation distribution http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get geolocation distribution status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_Roles_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/roles/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete role http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAdmin_Roles_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"name": "Updated Role",
	}
	resp, _, err := c.DoJSON("PATCH", "/api/admin/roles/00000000-0000-0000-0000-000000000000", payload, admin.Token)
	if err != nil {
		t.Fatalf("update role http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAdmin_Files_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/files/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete file http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAdmin_IpInfoTokens_Get_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("GET", "/api/admin/ipinfo-tokens/test-provider", nil, admin.Token)
	if err != nil {
		t.Fatalf("get ipinfo token http error: %v", err)
	}
	// 可能返回 200（空数据）或 404
	if resp.StatusCode != 200 && resp.StatusCode != 404 {
		t.Fatalf("expected 200 or 404, got %d", resp.StatusCode)
	}
}

func TestAdmin_DataCleanup(t *testing.T) {
	// 这是危险操作，只验证接口存在即可
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 不带确认参数，应该拒绝
	resp, _, err := c.DoJSON("POST", "/admin/data/cleanup/all", nil, admin.Token)
	if err != nil {
		t.Fatalf("cleanup http error: %v", err)
	}
	// 应该返回 400（缺少确认）或 403（权限不足）或 404
	if resp.StatusCode != 400 && resp.StatusCode != 403 && resp.StatusCode != 404 {
		t.Fatalf("expected 400/403/404, got %d", resp.StatusCode)
	}
}

func TestAdmin_TestGeolocationApi(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"ip": "8.8.8.8",
	}
	resp, body, err := c.DoJSON("POST", "/api/admin/test-geolocation-api", payload, admin.Token)
	if err != nil {
		t.Fatalf("test geolocation api http error: %v", err)
	}
	// 可能返回 200 或 400（没配置 provider）
	if resp.StatusCode != 200 && resp.StatusCode != 400 && resp.StatusCode != 404 {
		t.Fatalf("test geolocation api status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_MultipartUpload_Abort_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("POST", "/api/admin/uploads/multipart/sessions/00000000-0000-0000-0000-000000000000/abort", nil, admin.Token)
	if err != nil {
		t.Fatalf("abort multipart http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAdmin_PushProvider_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"enabled": true,
	}
	resp, _, err := c.DoJSON("PUT", "/api/admin/settings/push/providers/nonexistent-provider", payload, admin.Token)
	if err != nil {
		t.Fatalf("update push provider http error: %v", err)
	}
	// 可能返回 404 或 400
	if resp.StatusCode != 404 && resp.StatusCode != 400 {
		t.Fatalf("expected 404 or 400, got %d", resp.StatusCode)
	}
}
