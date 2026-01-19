package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 热更新管理测试

func TestHotUpdates_List(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/hot-updates", nil, admin.Token)
	if err != nil {
		t.Fatalf("list hot updates http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list hot updates status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestHotUpdates_Events(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/hot-updates/events", nil, admin.Token)
	if err != nil {
		t.Fatalf("list hot update events http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list hot update events status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestHotUpdates_GetById_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("GET", "/api/admin/hot-updates/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("get hot update http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestHotUpdates_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"description": "Updated description",
	}
	resp, _, err := c.DoJSON("PATCH", "/api/admin/hot-updates/00000000-0000-0000-0000-000000000000", payload, admin.Token)
	if err != nil {
		t.Fatalf("update hot update http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestHotUpdates_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/hot-updates/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete hot update http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestHotUpdates_Activate_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("POST", "/api/admin/hot-updates/00000000-0000-0000-0000-000000000000/activate", nil, admin.Token)
	if err != nil {
		t.Fatalf("activate hot update http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestHotUpdates_Deactivate_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("POST", "/api/admin/hot-updates/00000000-0000-0000-0000-000000000000/deactivate", nil, admin.Token)
	if err != nil {
		t.Fatalf("deactivate hot update http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}
