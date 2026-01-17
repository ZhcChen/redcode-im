package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminMeResponse struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

func TestAdmin_LoginMeAndDashboard(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin smoke test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respMe, bodyMe, err := c.DoJSON("GET", "/auth/admin/me", nil, admin.Token)
	if err != nil {
		t.Fatalf("admin me http error: %v", err)
	}
	if respMe.StatusCode != 200 {
		t.Fatalf("admin me status=%d body=%s", respMe.StatusCode, string(bodyMe))
	}

	// 仅验证最小字段存在即可，避免对后台返回结构过度耦合
	var me adminMeResponse
	if err := testutil.DecodeJSON(bodyMe, &me); err != nil {
		t.Fatalf("admin me decode: %v body=%s", err, string(bodyMe))
	}
	if me.ID == "" || me.Username == "" {
		t.Fatalf("admin me missing fields: body=%s", string(bodyMe))
	}

	respDash, bodyDash, err := c.DoJSON("GET", "/api/dashboard/stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("dashboard stats http error: %v", err)
	}
	if respDash.StatusCode != 200 {
		t.Fatalf("dashboard stats status=%d body=%s", respDash.StatusCode, string(bodyDash))
	}

	// 普通用户 token 访问 admin-only 路由应返回 403
	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)
	respForbidden, bodyForbidden, err := c.DoJSON("GET", "/api/dashboard/stats", nil, login.Token)
	if err != nil {
		t.Fatalf("dashboard stats (non-admin) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected non-admin status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}
}
