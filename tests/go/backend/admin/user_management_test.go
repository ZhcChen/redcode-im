package admin_test

import (
	"fmt"
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type userOpResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdmin_ResetUserPassword(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin reset password test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	username := testutil.UniquePhone()
	oldPass := "OldPassw0rd!"
	newPass := "NewPassw0rd!"

	user := testutil.RegisterUser(t, c, username, oldPass)

	resp, body, err := c.DoJSON("POST", fmt.Sprintf("/api/admin/users/%s/password/reset", user.ID), map[string]any{
		"new_password": newPass,
	}, admin.Token)
	if err != nil {
		t.Fatalf("admin reset user password http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("admin reset user password status=%d body=%s", resp.StatusCode, string(body))
	}
	var out userOpResponse
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode admin reset password: %v body=%s", err, string(body))
	}
	if !out.Success {
		t.Fatalf("expected reset success=true, got false message=%q body=%s", out.Message, string(body))
	}

	// 旧密码应失效
	respOld, _, err := c.DoJSON("POST", "/auth/login", map[string]any{
		"username": username,
		"password": oldPass,
	}, "")
	if err != nil {
		t.Fatalf("login (old password) http error: %v", err)
	}
	if respOld.StatusCode == 200 {
		t.Fatalf("expected old password login fail, got status=200")
	}

	// 新密码可登录
	login := testutil.Login(t, c, username, newPass)
	if login.Token == "" {
		t.Fatalf("login (new password) missing token: %+v", login)
	}
}

