package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminFileUploadAuditAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestAdminFileUploadAuditLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("list invalid provider id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/file-upload-audit/tasks?providerId=not-a-uuid",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("list file upload audit tasks request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminFileUploadAuditError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.file_upload_audit_provider_id_invalid",
			"provider_id is invalid.",
			nil,
		)
	})

	t.Run("get invalid task id chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/file-upload-audit/tasks/not-a-uuid",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get file upload audit task request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminFileUploadAuditError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.file_upload_audit_task_id_invalid",
			"无效的 task_id",
			nil,
		)
	})

	t.Run("get task not found english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/file-upload-audit/tasks/550e8400-e29b-41d4-a716-446655440020",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get file upload audit task request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminFileUploadAuditError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.file_upload_audit_task_not_found",
			"Audit task was not found.",
			nil,
		)
	})

	t.Run("requeue invalid task id chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/file-upload-audit/tasks/not-a-uuid/requeue",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("requeue file upload audit task request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminFileUploadAuditError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.file_upload_audit_task_id_invalid",
			"无效的 task_id",
			nil,
		)
	})

	t.Run("requeue task not found english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/file-upload-audit/tasks/550e8400-e29b-41d4-a716-446655440021/requeue",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("requeue file upload audit task request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminFileUploadAuditError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.file_upload_audit_task_not_found",
			"Audit task was not found.",
			nil,
		)
	})
}

func assertLocalizedAdminFileUploadAuditError(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
	wantCode int,
	wantKey string,
	wantMessage string,
	wantParams map[string]string,
) {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminFileUploadAuditAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized admin file upload audit error response failed: %v", err)
	}

	if payload.Code != wantCode {
		t.Fatalf("unexpected code: want %d got %d", wantCode, payload.Code)
	}
	if payload.MessageKey != wantKey {
		t.Fatalf("unexpected message_key: want %s got %s", wantKey, payload.MessageKey)
	}
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: want %s got %s", wantMessage, payload.Message)
	}
	if wantParams == nil {
		if payload.MessageParams != nil {
			t.Fatalf("expected nil message_params, got %+v", payload.MessageParams)
		}
	} else {
		if payload.MessageParams == nil {
			t.Fatalf("expected message_params, got nil")
		}
		for key, value := range wantParams {
			if payload.MessageParams[key] != value {
				t.Fatalf("unexpected message_params[%s]: want %s got %s", key, value, payload.MessageParams[key])
			}
		}
	}
	if payload.Details != nil {
		t.Fatalf("expected nil details, got %q", *payload.Details)
	}
}
