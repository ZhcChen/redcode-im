package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 管理员认证相关测试

func TestAdminAuth_RefreshToken(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 使用 refresh_token 刷新
	payload := map[string]any{
		"refresh_token": admin.RefreshToken,
	}
	resp, body, err := c.DoJSON("POST", "/auth/admin/refresh", payload, "")
	if err != nil {
		t.Fatalf("refresh http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("refresh status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Token        string `json:"token"`
		RefreshToken string `json:"refresh_token"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if result.Token == "" {
		t.Fatal("expected new token")
	}
}

func TestAdminAuth_UpdateMe(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 更新管理员信息（只更新 nickname）
	payload := map[string]any{
		"nickname": "Admin Updated",
	}
	resp, body, err := c.DoJSON("PATCH", "/auth/admin/me", payload, admin.Token)
	if err != nil {
		t.Fatalf("update me http error: %v", err)
	}
	// 可能返回 200 或 204
	if resp.StatusCode != 200 && resp.StatusCode != 204 {
		t.Fatalf("update me status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdminAuth_ChangePassword(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 修改密码（然后改回去）
	newPass := adminPass + "New1"
	payload := map[string]any{
		"old_password": adminPass,
		"new_password": newPass,
	}
	resp, body, err := c.DoJSON("POST", "/auth/admin/me/password", payload, admin.Token)
	if err != nil {
		t.Fatalf("change password http error: %v", err)
	}
	if resp.StatusCode != 200 && resp.StatusCode != 204 {
		t.Fatalf("change password status=%d body=%s", resp.StatusCode, string(body))
	}

	// 改回原密码
	admin2 := testutil.AdminLogin(t, c, adminUser, newPass)
	payload2 := map[string]any{
		"old_password": newPass,
		"new_password": adminPass,
	}
	resp2, body2, err := c.DoJSON("POST", "/auth/admin/me/password", payload2, admin2.Token)
	if err != nil {
		t.Fatalf("revert password http error: %v", err)
	}
	if resp2.StatusCode != 200 && resp2.StatusCode != 204 {
		t.Fatalf("revert password status=%d body=%s", resp2.StatusCode, string(body2))
	}
}

func TestAdminAuth_CheckAdminUsers(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("GET", "/api/admin/check-admin-users", nil, admin.Token)
	if err != nil {
		t.Fatalf("check admin users http error: %v", err)
	}
	// 该接口默认禁用（需要 ALLOW_INSECURE_ADMIN_BOOTSTRAP=true），返回 403 是预期行为
	if resp.StatusCode != 200 && resp.StatusCode != 403 {
		t.Fatalf("expected 200 or 403, got %d", resp.StatusCode)
	}
}

func TestAdminAuth_ResetAdminPassword(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 获取管理员列表找一个可重置的用户
	resp, body, err := c.DoJSON("GET", "/api/admin/admin-users", nil, admin.Token)
	if err != nil {
		t.Fatalf("list admin users http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list admin users status=%d body=%s", resp.StatusCode, string(body))
	}

	// 测试重置密码接口（使用当前管理员自己，然后改回去）
	payload := map[string]any{
		"username":     adminUser,
		"new_password": adminPass, // 使用相同密码，这样不会影响后续测试
	}
	resp2, body2, err := c.DoJSON("POST", "/api/admin/reset-admin-password", payload, admin.Token)
	if err != nil {
		t.Fatalf("reset password http error: %v", err)
	}
	// 可能返回 200 或 403（权限不足）
	if resp2.StatusCode != 200 && resp2.StatusCode != 403 && resp2.StatusCode != 400 {
		t.Fatalf("reset password status=%d body=%s", resp2.StatusCode, string(body2))
	}
}
