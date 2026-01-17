package auth_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type resetPasswordResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAuth_ResetPassword_WithUniversalSMSCode(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip password reset test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 读取原始 captcha 设置，用于回滚（避免影响其他用例/手工联调）
	respGet, bodyGet, err := c.DoJSON("GET", "/api/admin/settings/captcha", nil, admin.Token)
	if err != nil {
		t.Fatalf("get captcha setting http error: %v", err)
	}
	if respGet.StatusCode != 200 {
		t.Fatalf("get captcha setting status=%d body=%s", respGet.StatusCode, string(bodyGet))
	}
	var original captchaSetting
	if err := testutil.DecodeJSON(bodyGet, &original); err != nil {
		t.Fatalf("decode captcha setting: %v body=%s", err, string(bodyGet))
	}

	universalCode := "999999"
	update := map[string]any{
		"enabled":                   true,
		"captcha_code":              universalCode,
		"description":               "go-test",
		"require_captcha_for_login": true,
	}
	respSet, bodySet, err := c.DoJSON("POST", "/api/admin/settings/captcha", update, admin.Token)
	if err != nil {
		t.Fatalf("update captcha setting http error: %v", err)
	}
	if respSet.StatusCode != 200 {
		t.Fatalf("update captcha setting status=%d body=%s", respSet.StatusCode, string(bodySet))
	}

	t.Cleanup(func() {
		_, _, _ = c.DoJSON("POST", "/api/admin/settings/captcha", map[string]any{
			"enabled":                   original.Enabled,
			"captcha_code":              original.CaptchaCode,
			"description":               original.Description,
			"require_captcha_for_login": original.RequireCaptchaForLogin,
		}, admin.Token)
	})

	phone := testutil.UniquePhone()
	oldPass := "OldPassw0rd!"
	newPass := "NewPassw0rd!"

	testutil.RegisterUser(t, c, phone, oldPass)
	login := testutil.Login(t, c, phone, oldPass)

	// 发送一次验证码（真实链路：先 send，再 reset；reset 用通用验证码避免读取 Redis 随机码）
	respSend, bodySend, err := c.DoJSON("POST", "/auth/sms/send", map[string]any{"phone": phone}, "")
	if err != nil {
		t.Fatalf("send sms http error: %v", err)
	}
	if respSend.StatusCode != 200 {
		t.Fatalf("send sms status=%d body=%s", respSend.StatusCode, string(bodySend))
	}

	respReset, bodyReset, err := c.DoJSON("POST", "/auth/password/reset", map[string]any{
		"phone":        phone,
		"code":         universalCode,
		"new_password": newPass,
	}, login.Token)
	if err != nil {
		t.Fatalf("reset password http error: %v", err)
	}
	if respReset.StatusCode != 200 {
		t.Fatalf("reset password status=%d body=%s", respReset.StatusCode, string(bodyReset))
	}
	var rr resetPasswordResponse
	if err := testutil.DecodeJSON(bodyReset, &rr); err != nil {
		t.Fatalf("decode reset password: %v body=%s", err, string(bodyReset))
	}
	if !rr.Success {
		t.Fatalf("expected reset password success=true, body=%s", string(bodyReset))
	}

	// 旧密码应失效
	respOld, _, err := c.DoJSON("POST", "/auth/login", map[string]any{
		"username": phone,
		"password": oldPass,
	}, "")
	if err != nil {
		t.Fatalf("login (old password) http error: %v", err)
	}
	if respOld.StatusCode == 200 {
		t.Fatalf("expected old password login fail, got status=200")
	}

	// 新密码可登录
	login2 := testutil.Login(t, c, phone, newPass)
	if login2.Token == "" {
		t.Fatalf("login (new password) missing token: %+v", login2)
	}
}

