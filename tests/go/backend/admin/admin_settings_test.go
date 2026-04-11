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

type messageRuntimeSettingsPayload struct {
	ServerStorageMode string `json:"server_storage_mode"`
	ContentAuditMode  string `json:"content_audit_mode"`
}

type messageRuntimeSettingsResponse struct {
	ServerStorageMode string  `json:"server_storage_mode"`
	ContentAuditMode  string  `json:"content_audit_mode"`
	UpdatedAt         *string `json:"updated_at"`
	UpdatedBy         *string `json:"updated_by"`
}

func invertMessageRuntimeSettings(current messageRuntimeSettingsPayload) messageRuntimeSettingsPayload {
	next := messageRuntimeSettingsPayload{
		ServerStorageMode: current.ServerStorageMode,
		ContentAuditMode:  current.ContentAuditMode,
	}

	if next.ServerStorageMode == "persist" {
		next.ServerStorageMode = "relay_only"
	} else {
		next.ServerStorageMode = "persist"
	}

	if next.ContentAuditMode == "plaintext" {
		next.ContentAuditMode = "e2ee"
	} else {
		next.ContentAuditMode = "plaintext"
	}

	return next
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

func TestAdminSettings_MessageRuntimeSettings_OKAndValidationError(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	getReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/message-runtime", admin.Token, nil)
	getResp, err := c.HTTP.Do(getReq)
	if err != nil {
		t.Fatalf("get message-runtime failed: %v", err)
	}
	defer getResp.Body.Close()
	if getResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(getResp.Body)
		t.Fatalf("get message-runtime expect 200, got %d: %s", getResp.StatusCode, string(body))
	}

	var current messageRuntimeSettingsResponse
	if err := json.NewDecoder(getResp.Body).Decode(&current); err != nil {
		t.Fatalf("decode message-runtime failed: %v", err)
	}
	if current.ServerStorageMode != "persist" && current.ServerStorageMode != "relay_only" {
		t.Fatalf("unexpected server_storage_mode: %+v", current)
	}
	if current.ContentAuditMode != "plaintext" && current.ContentAuditMode != "e2ee" {
		t.Fatalf("unexpected content_audit_mode: %+v", current)
	}

	invalidReq := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/message-runtime", admin.Token, messageRuntimeSettingsPayload{
		ServerStorageMode: "archive",
		ContentAuditMode:  "sealed",
	})
	invalidResp, err := c.HTTP.Do(invalidReq)
	if err != nil {
		t.Fatalf("put invalid message-runtime failed: %v", err)
	}
	defer invalidResp.Body.Close()
	if invalidResp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(invalidResp.Body)
		t.Fatalf("invalid message-runtime expect 400, got %d: %s", invalidResp.StatusCode, string(body))
	}
	var invalidPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(invalidResp.Body).Decode(&invalidPayload); err != nil {
		t.Fatalf("decode invalid message-runtime response failed: %v", err)
	}
	if invalidPayload.Code != 42201 || !strings.Contains(invalidPayload.Message, "server_storage_mode") {
		t.Fatalf("invalid message-runtime response mismatch: %+v", invalidPayload)
	}

	original := messageRuntimeSettingsPayload{
		ServerStorageMode: current.ServerStorageMode,
		ContentAuditMode:  current.ContentAuditMode,
	}
	target := invertMessageRuntimeSettings(original)

	restoreSettings := func() {
		restoreReq := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/message-runtime", admin.Token, original)
		restoreResp, restoreErr := c.HTTP.Do(restoreReq)
		if restoreErr != nil {
			t.Fatalf("restore message-runtime failed: %v", restoreErr)
		}
		defer restoreResp.Body.Close()
		if restoreResp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(restoreResp.Body)
			t.Fatalf("restore message-runtime expect 200, got %d: %s", restoreResp.StatusCode, string(body))
		}
	}
	defer restoreSettings()

	updateReq := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/message-runtime", admin.Token, target)
	updateResp, err := c.HTTP.Do(updateReq)
	if err != nil {
		t.Fatalf("put valid message-runtime failed: %v", err)
	}
	defer updateResp.Body.Close()
	if updateResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(updateResp.Body)
		t.Fatalf("valid message-runtime expect 200, got %d: %s", updateResp.StatusCode, string(body))
	}

	var updated messageRuntimeSettingsResponse
	if err := json.NewDecoder(updateResp.Body).Decode(&updated); err != nil {
		t.Fatalf("decode updated message-runtime failed: %v", err)
	}
	if updated.ServerStorageMode != target.ServerStorageMode || updated.ContentAuditMode != target.ContentAuditMode {
		t.Fatalf("updated message-runtime mismatch: expect %+v, got %+v", target, updated)
	}
	if updated.UpdatedAt == nil || strings.TrimSpace(*updated.UpdatedAt) == "" {
		t.Fatalf("updated message-runtime missing updated_at: %+v", updated)
	}
	if updated.UpdatedBy == nil || strings.TrimSpace(*updated.UpdatedBy) == "" {
		t.Fatalf("updated message-runtime missing updated_by: %+v", updated)
	}

	verifyReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/message-runtime", admin.Token, nil)
	verifyResp, err := c.HTTP.Do(verifyReq)
	if err != nil {
		t.Fatalf("re-get message-runtime failed: %v", err)
	}
	defer verifyResp.Body.Close()
	if verifyResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(verifyResp.Body)
		t.Fatalf("re-get message-runtime expect 200, got %d: %s", verifyResp.StatusCode, string(body))
	}

	var persisted messageRuntimeSettingsResponse
	if err := json.NewDecoder(verifyResp.Body).Decode(&persisted); err != nil {
		t.Fatalf("decode persisted message-runtime failed: %v", err)
	}
	if persisted.ServerStorageMode != target.ServerStorageMode || persisted.ContentAuditMode != target.ContentAuditMode {
		t.Fatalf("persisted message-runtime mismatch: expect %+v, got %+v", target, persisted)
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
