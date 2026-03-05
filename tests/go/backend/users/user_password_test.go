package users_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestChangePassword_WrongOldThenSuccess(t *testing.T) {
	c := testutil.NewClient()

	username := testutil.UniqueUsername("pwd")
	oldPassword := "pass123456"
	newPassword := "newpass654321"

	login := registerAndLogin(t, c, username, oldPassword)

	wrongOldReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/users/me/password", login.Token, map[string]any{
		"old_password": "wrong-password",
		"new_password": newPassword,
	})
	wrongOldResp, err := c.HTTP.Do(wrongOldReq)
	if err != nil {
		t.Fatalf("change password with wrong old password failed: %v", err)
	}
	defer wrongOldResp.Body.Close()
	if wrongOldResp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(wrongOldResp.Body)
		t.Fatalf("change password with wrong old password expect 400, got %d: %s", wrongOldResp.StatusCode, string(body))
	}
	var wrongPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(wrongOldResp.Body).Decode(&wrongPayload); err != nil {
		t.Fatalf("decode wrong old password response failed: %v", err)
	}
	if wrongPayload.Code != 42201 || !strings.Contains(wrongPayload.Message, "旧密码错误") {
		t.Fatalf("wrong old password response mismatch: %+v", wrongPayload)
	}

	successReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/users/me/password", login.Token, map[string]any{
		"old_password": oldPassword,
		"new_password": newPassword,
	})
	successResp, err := c.HTTP.Do(successReq)
	if err != nil {
		t.Fatalf("change password request failed: %v", err)
	}
	defer successResp.Body.Close()
	if successResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(successResp.Body)
		t.Fatalf("change password expect 200, got %d: %s", successResp.StatusCode, string(body))
	}
	var successPayload struct {
		Success bool   `json:"success"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(successResp.Body).Decode(&successPayload); err != nil {
		t.Fatalf("decode change password success response failed: %v", err)
	}
	if !successPayload.Success {
		t.Fatalf("change password response expect success=true, got %+v", successPayload)
	}

	oldLoginStatus, oldLoginBody := loginStatus(c, username, oldPassword)
	if oldLoginStatus == http.StatusOK {
		t.Fatalf("old password should be invalid after change, got status 200: %s", oldLoginBody)
	}

	loginNew := testutil.LoginWithPassword(t, c, username, newPassword)
	if loginNew.Token == "" {
		t.Fatalf("login with new password returns empty token")
	}
}

func loginStatus(c *testutil.Client, username, password string) (int, string) {
	payload := map[string]any{
		"username": username,
		"password": password,
	}
	raw, _ := json.Marshal(payload)
	resp, err := c.HTTP.Post(c.BaseURL+"/auth/login", "application/json", bytes.NewReader(raw))
	if err != nil {
		return 0, err.Error()
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(body)
}
