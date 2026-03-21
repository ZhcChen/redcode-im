package auth_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type captchaSetting struct {
	Enabled                bool   `json:"enabled"`
	CaptchaCode            string `json:"captcha_code"`
	Description            string `json:"description"`
	RequireCaptchaForLogin bool   `json:"require_captcha_for_login"`
}

func TestSMSLogin_WithCaptchaSetting_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	before := getCaptchaSetting(t, c, admin.Token)
	defer updateCaptchaSetting(t, c, admin.Token, before)

	testSetting := captchaSetting{
		Enabled:                true,
		CaptchaCode:            "654321",
		Description:            "sms login test",
		RequireCaptchaForLogin: true,
	}
	updateCaptchaSetting(t, c, admin.Token, testSetting)

	phone := testutil.UniqueUsername("sms")

	sendReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/auth/sms/send", "", map[string]any{
		"phone": phone,
	})
	sendResp, err := c.HTTP.Do(sendReq)
	if err != nil {
		t.Fatalf("send sms failed: %v", err)
	}
	defer sendResp.Body.Close()
	if sendResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sendResp.Body)
		t.Fatalf("send sms expect 200, got %d: %s", sendResp.StatusCode, string(body))
	}
	var sendPayload struct {
		Success bool   `json:"success"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(sendResp.Body).Decode(&sendPayload); err != nil {
		t.Fatalf("decode send sms response failed: %v", err)
	}
	if !sendPayload.Success {
		t.Fatalf("send sms expect success=true, got %+v", sendPayload)
	}

	wrongReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/auth/login/sms", "", map[string]any{
		"phone": phone,
		"code":  "000000",
	})
	wrongResp, err := c.HTTP.Do(wrongReq)
	if err != nil {
		t.Fatalf("sms login with wrong code failed: %v", err)
	}
	defer wrongResp.Body.Close()
	if wrongResp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(wrongResp.Body)
		t.Fatalf("sms login with wrong code expect 400, got %d: %s", wrongResp.StatusCode, string(body))
	}
	var wrongPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(wrongResp.Body).Decode(&wrongPayload); err != nil {
		t.Fatalf("decode sms login wrong response failed: %v", err)
	}
	if wrongPayload.Code != 42201 || !strings.Contains(wrongPayload.Message, "验证码错误或已过期") {
		t.Fatalf("sms login wrong response mismatch: %+v", wrongPayload)
	}

	successReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/auth/login/sms", "", map[string]any{
		"phone": phone,
		"code":  testSetting.CaptchaCode,
	})
	successResp, err := c.HTTP.Do(successReq)
	if err != nil {
		t.Fatalf("sms login failed: %v", err)
	}
	defer successResp.Body.Close()
	if successResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(successResp.Body)
		t.Fatalf("sms login expect 200, got %d: %s", successResp.StatusCode, string(body))
	}
	var loginPayload testutil.LoginResponse
	if err := json.NewDecoder(successResp.Body).Decode(&loginPayload); err != nil {
		t.Fatalf("decode sms login response failed: %v", err)
	}
	if loginPayload.Token == "" || loginPayload.RefreshToken == "" || loginPayload.User.ID == "" {
		t.Fatalf("invalid sms login response: %+v", loginPayload)
	}
	if loginPayload.User.Username != phone {
		t.Fatalf("sms login auto-created user mismatch: expect %s, got %s", phone, loginPayload.User.Username)
	}

	meReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/auth/me", loginPayload.Token, nil)
	meResp, err := c.HTTP.Do(meReq)
	if err != nil {
		t.Fatalf("request /auth/me after sms login failed: %v", err)
	}
	defer meResp.Body.Close()
	if meResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(meResp.Body)
		t.Fatalf("/auth/me after sms login expect 200, got %d: %s", meResp.StatusCode, string(body))
	}
}

func getCaptchaSetting(t *testing.T, c *testutil.Client, adminToken string) captchaSetting {
	t.Helper()
	req := testutil.NewAuthedJSONRequestWithToken(http.MethodGet, c.BaseURL+"/api/admin/settings/captcha", adminToken, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("get captcha setting failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("get captcha setting expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload captchaSetting
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode captcha setting failed: %v", err)
	}
	return payload
}

func updateCaptchaSetting(t *testing.T, c *testutil.Client, adminToken string, setting captchaSetting) {
	t.Helper()
	req := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/api/admin/settings/captcha", adminToken, map[string]any{
		"enabled":                   setting.Enabled,
		"captcha_code":              setting.CaptchaCode,
		"description":               setting.Description,
		"require_captcha_for_login": setting.RequireCaptchaForLogin,
	})
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("update captcha setting failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("update captcha setting expect 200, got %d: %s", resp.StatusCode, string(body))
	}
}
