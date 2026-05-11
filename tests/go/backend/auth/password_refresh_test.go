package auth_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestPasswordLoginAndRefresh_OK(t *testing.T) {
	c := testutil.NewClient()
	username := testutil.UniqueEmail("auth_user")
	password := "pass123456"

	registered := testutil.RegisterUser(t, c, username, password)
	loginResp := testutil.LoginWithPassword(t, c, username, password)

	if loginResp.User.ID != registered.ID {
		t.Fatalf("login user id mismatch: expect %s, got %s", registered.ID, loginResp.User.ID)
	}
	if loginResp.User.Email != username {
		t.Fatalf("login user email mismatch: expect %s, got %s", username, loginResp.User.Email)
	}

	refreshResp := testutil.RefreshToken(t, c, loginResp.RefreshToken)
	if refreshResp.User.ID != registered.ID {
		t.Fatalf("refresh user id mismatch: expect %s, got %s", registered.ID, refreshResp.User.ID)
	}

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/auth/me", refreshResp.Token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request /auth/me failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect /auth/me 200, got %d", resp.StatusCode)
	}
}

func TestEmailRegisterValidationAndDuplicate_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)
	password := "pass123456"

	beforeLimit := testutil.GetUserAccountLimitSetting(t, c, admin.Token)
	defer testutil.UpdateUserAccountLimitSetting(t, c, admin.Token, beforeLimit)
	testutil.UpdateUserAccountLimitSetting(t, c, admin.Token, testutil.UserAccountLimitSetting{
		EnablePhoneValidation:        true,
		EnableEmailValidation:        false,
		EnableLengthValidation:       false,
		MinLength:                    3,
		MaxLength:                    50,
		EnableAlphanumericValidation: false,
	})

	before := getCaptchaSetting(t, c, admin.Token)
	defer updateCaptchaSetting(t, c, admin.Token, before)
	updateCaptchaSetting(t, c, admin.Token, captchaSetting{
		Enabled:                true,
		CaptchaCode:            "246810",
		Description:            "email register should not require captcha",
		RequireCaptchaForLogin: true,
	})

	invalidReq := map[string]any{
		"email":    "not-an-email",
		"password": password,
	}
	invalidStatus, invalidBody := postJSON(c, c.BaseURL+"/auth/register", invalidReq)
	if invalidStatus != http.StatusBadRequest || !strings.Contains(invalidBody, "邮箱格式不正确") {
		t.Fatalf("invalid email register mismatch: status=%d body=%s", invalidStatus, invalidBody)
	}

	email := testutil.UniqueEmail("dup")
	registerStatus, registerBody := postJSON(c, c.BaseURL+"/auth/register", map[string]any{
		"username": strings.ToUpper(email),
		"email":    strings.ToUpper(email),
		"password": password,
	})
	if registerStatus != http.StatusOK {
		t.Fatalf("email register should ignore captcha and accept username=email: status=%d body=%s", registerStatus, registerBody)
	}
	var registered testutil.UserInfo
	if err := json.Unmarshal([]byte(registerBody), &registered); err != nil {
		t.Fatalf("decode register response failed: %v body=%s", err, registerBody)
	}
	if registered.Email != email {
		t.Fatalf("register email mismatch: expect %s, got %s", email, registered.Email)
	}

	duplicateStatus, duplicateBody := postJSON(c, c.BaseURL+"/auth/register", map[string]any{
		"email":    strings.ToUpper(email),
		"password": password,
	})
	if duplicateStatus != http.StatusConflict || !strings.Contains(duplicateBody, "邮箱已被使用") {
		t.Fatalf("duplicate email register mismatch: status=%d body=%s", duplicateStatus, duplicateBody)
	}
}

func TestEmailLoginWrongPasswordAndLegacyUsernameCompat_OK(t *testing.T) {
	c := testutil.NewClient()
	email := testutil.UniqueEmail("login")
	password := "pass123456"
	testutil.RegisterUser(t, c, email, password)

	wrongStatus, wrongBody := postJSON(c, c.BaseURL+"/auth/login", map[string]any{
		"email":    email,
		"password": "wrong-password",
	})
	if wrongStatus != http.StatusUnauthorized || !strings.Contains(wrongBody, "用户名或密码错误") {
		t.Fatalf("wrong password login mismatch: status=%d body=%s", wrongStatus, wrongBody)
	}

	legacyStatus, legacyBody := postJSON(c, c.BaseURL+"/auth/login", map[string]any{
		"username": email,
		"password": password,
	})
	if legacyStatus != http.StatusOK {
		t.Fatalf("legacy username login should still work: status=%d body=%s", legacyStatus, legacyBody)
	}
}

func postJSON(c *testutil.Client, url string, payload any) (int, string) {
	raw, _ := json.Marshal(payload)
	resp, err := c.HTTP.Post(url, "application/json", bytes.NewReader(raw))
	if err != nil {
		return 0, err.Error()
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(body)
}
