package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// App 版本管理测试

func TestAppVersions_List(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 需要指定 platform 参数
	resp, body, err := c.DoJSON("GET", "/api/admin/app-versions?platform=ios", nil, admin.Token)
	if err != nil {
		t.Fatalf("list app versions http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list app versions status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAppVersions_UploadSignature(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"platform":     "android",
		"filename":     "app-v1.0.0.apk",
		"content_type": "application/vnd.android.package-archive",
		"size":         1024000,
	}
	resp, body, err := c.DoJSON("POST", "/api/admin/app-versions/upload/signature", payload, admin.Token)
	if err != nil {
		t.Fatalf("upload signature http error: %v", err)
	}
	// 可能返回 200 或 400（缺少存储配置）
	if resp.StatusCode != 200 && resp.StatusCode != 400 && resp.StatusCode != 404 {
		t.Fatalf("upload signature status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAppVersions_GetById_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 使用不存在的 UUID
	resp, _, err := c.DoJSON("GET", "/api/admin/app-versions/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("get app version http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAppVersions_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"release_notes": "Updated notes",
	}
	resp, _, err := c.DoJSON("PATCH", "/api/admin/app-versions/00000000-0000-0000-0000-000000000000", payload, admin.Token)
	if err != nil {
		t.Fatalf("update app version http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAppVersions_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/app-versions/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete app version http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestAppVersions_Deactivate_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("POST", "/api/admin/app-versions/00000000-0000-0000-0000-000000000000/deactivate", nil, admin.Token)
	if err != nil {
		t.Fatalf("deactivate app version http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}
