package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type userAccountLimitPayload struct {
	EnablePhoneValidation        bool `json:"enable_phone_validation"`
	EnableEmailValidation        bool `json:"enable_email_validation"`
	EnableLengthValidation       bool `json:"enable_length_validation"`
	MinLength                    int  `json:"min_length"`
	MaxLength                    int  `json:"max_length"`
	EnableAlphanumericValidation bool `json:"enable_alphanumeric_validation"`
}

type uploadPolicyAdminResponse struct {
	Policy struct {
		Version              string `json:"version"`
		MaxTotalSizeMb       int    `json:"max_total_size_mb"`
		MaxAttachmentsPerMsg int    `json:"max_attachments_per_message"`
	} `json:"policy"`
	UpdatedAt *string `json:"updated_at"`
	UpdatedBy *string `json:"updated_by"`
}

func TestAdminSettings_UserAccountLimitAndUploadPolicy_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	limitReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/user-account-limit", admin.Token, nil)
	limitResp, err := c.HTTP.Do(limitReq)
	if err != nil {
		t.Fatalf("get user-account-limit failed: %v", err)
	}
	defer limitResp.Body.Close()
	if limitResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(limitResp.Body)
		t.Fatalf("get user-account-limit expect 200, got %d: %s", limitResp.StatusCode, string(body))
	}

	var current userAccountLimitPayload
	if err := json.NewDecoder(limitResp.Body).Decode(&current); err != nil {
		t.Fatalf("decode user-account-limit failed: %v", err)
	}

	invalidReq := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/user-account-limit", admin.Token, userAccountLimitPayload{
		EnablePhoneValidation:        false,
		EnableEmailValidation:        false,
		EnableLengthValidation:       false,
		MinLength:                    3,
		MaxLength:                    50,
		EnableAlphanumericValidation: false,
	})
	invalidResp, err := c.HTTP.Do(invalidReq)
	if err != nil {
		t.Fatalf("put invalid user-account-limit failed: %v", err)
	}
	defer invalidResp.Body.Close()
	if invalidResp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(invalidResp.Body)
		t.Fatalf("invalid user-account-limit expect 400, got %d: %s", invalidResp.StatusCode, string(body))
	}
	var invalidPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(invalidResp.Body).Decode(&invalidPayload); err != nil {
		t.Fatalf("decode invalid user-account-limit response failed: %v", err)
	}
	if invalidPayload.Code != 42201 || !strings.Contains(invalidPayload.Message, "至少需要启用一种校验规则") {
		t.Fatalf("invalid user-account-limit response mismatch: %+v", invalidPayload)
	}

	// 用当前值回写，验证更新契约（避免引入全局配置副作用）
	validReq := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/user-account-limit", admin.Token, current)
	validResp, err := c.HTTP.Do(validReq)
	if err != nil {
		t.Fatalf("put valid user-account-limit failed: %v", err)
	}
	defer validResp.Body.Close()
	if validResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(validResp.Body)
		t.Fatalf("valid user-account-limit expect 200, got %d: %s", validResp.StatusCode, string(body))
	}
	var updated userAccountLimitPayload
	if err := json.NewDecoder(validResp.Body).Decode(&updated); err != nil {
		t.Fatalf("decode valid user-account-limit response failed: %v", err)
	}
	if updated != current {
		t.Fatalf("user-account-limit round-trip mismatch: expect %+v, got %+v", current, updated)
	}

	uploadReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/upload-policy", admin.Token, nil)
	uploadResp, err := c.HTTP.Do(uploadReq)
	if err != nil {
		t.Fatalf("get upload-policy failed: %v", err)
	}
	defer uploadResp.Body.Close()
	if uploadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(uploadResp.Body)
		t.Fatalf("get upload-policy expect 200, got %d: %s", uploadResp.StatusCode, string(body))
	}
	var uploadPolicy uploadPolicyAdminResponse
	if err := json.NewDecoder(uploadResp.Body).Decode(&uploadPolicy); err != nil {
		t.Fatalf("decode upload-policy response failed: %v", err)
	}
	if strings.TrimSpace(uploadPolicy.Policy.Version) == "" {
		t.Fatalf("upload-policy version is empty: %+v", uploadPolicy)
	}
	if uploadPolicy.Policy.MaxTotalSizeMb <= 0 || uploadPolicy.Policy.MaxAttachmentsPerMsg < 0 {
		t.Fatalf("upload-policy numeric constraints invalid: %+v", uploadPolicy.Policy)
	}
}

func TestAdminSettings_NonAdminShouldBeForbidden(t *testing.T) {
	c := testutil.NewClient()
	username := testutil.UniqueUsername("adminset")
	password := "pass123456"

	testutil.RegisterUser(t, c, username, password)
	login := testutil.LoginWithPassword(t, c, username, password)

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/user-account-limit", login.Token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("non-admin get user-account-limit failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("non-admin get user-account-limit expect 403, got %d: %s", resp.StatusCode, string(body))
	}
}
