package auth_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type captchaSetting struct {
	Enabled                bool   `json:"enabled"`
	CaptchaCode            string `json:"captcha_code"`
	Description            string `json:"description"`
	RequireCaptchaForLogin bool   `json:"require_captcha_for_login"`
	UpdatedAt              string `json:"updated_at"`
}

type smsSendResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type smsLoginResponse struct {
	Token string `json:"token"`
	User  struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
	RefreshToken string `json:"refresh_token"`
}

func TestAuth_SMSLogin_UniversalCodeFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip sms login test")
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

	// send sms should be enabled now
	respSend, bodySend, err := c.DoJSON("POST", "/auth/sms/send", map[string]any{"phone": phone}, "")
	if err != nil {
		t.Fatalf("send sms http error: %v", err)
	}
	if respSend.StatusCode != 200 {
		t.Fatalf("send sms status=%d body=%s", respSend.StatusCode, string(bodySend))
	}
	var send smsSendResponse
	if err := testutil.DecodeJSON(bodySend, &send); err != nil {
		t.Fatalf("decode send sms: %v body=%s", err, string(bodySend))
	}
	if !send.Success {
		t.Fatalf("expected send sms success=true, body=%s", string(bodySend))
	}

	// login via universal captcha code (无需读取 Redis 随机验证码)
	respLogin, bodyLogin, err := c.DoJSON("POST", "/auth/login/sms", map[string]any{
		"phone": phone,
		"code":  universalCode,
	}, "")
	if err != nil {
		t.Fatalf("sms login http error: %v", err)
	}
	if respLogin.StatusCode != 200 {
		t.Fatalf("sms login status=%d body=%s", respLogin.StatusCode, string(bodyLogin))
	}
	var lr smsLoginResponse
	if err := testutil.DecodeJSON(bodyLogin, &lr); err != nil {
		t.Fatalf("decode sms login: %v body=%s", err, string(bodyLogin))
	}
	if lr.Token == "" || lr.User.ID == "" || lr.User.Username != phone {
		t.Fatalf("unexpected sms login response: token=%q user_id=%q username=%q body=%s", lr.Token, lr.User.ID, lr.User.Username, string(bodyLogin))
	}
	if lr.RefreshToken == "" {
		t.Fatalf("expected refresh_token non-empty: body=%s", string(bodyLogin))
	}

	// wrong code should fail
	respBad, bodyBad, err := c.DoJSON("POST", "/auth/login/sms", map[string]any{
		"phone": phone,
		"code":  "000000",
	}, "")
	if err != nil {
		t.Fatalf("sms login (bad code) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected sms login (bad code) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}

	// 再次登录应允许（通用验证码）
	time.Sleep(50 * time.Millisecond)
	respLogin2, bodyLogin2, err := c.DoJSON("POST", "/auth/login/sms", map[string]any{
		"phone": phone,
		"code":  universalCode,
	}, "")
	if err != nil {
		t.Fatalf("sms login2 http error: %v", err)
	}
	if respLogin2.StatusCode != 200 {
		t.Fatalf("sms login2 status=%d body=%s", respLogin2.StatusCode, string(bodyLogin2))
	}
}

func TestAuth_OAuthLogin_MissingConfigReturns503(t *testing.T) {
	c := testutil.NewClient()

	resp, body, err := c.DoJSON("POST", "/auth/login/oauth", map[string]any{
		"provider": "google",
		"id_token": "dummy",
	}, "")
	if err != nil {
		t.Fatalf("oauth login http error: %v", err)
	}
	// 测试栈默认未配置 GOOGLE_OAUTH_CLIENT_ID，因此应返回 503
	if resp.StatusCode != 503 {
		t.Fatalf("expected oauth login status=503, got %d body=%s", resp.StatusCode, string(body))
	}
}
