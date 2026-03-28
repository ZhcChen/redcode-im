package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type adminFileUploadAuditAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

type adminFileUploadAuditTaskListResponse struct {
	Tasks []struct {
		ID        string `json:"id"`
		ObjectKey string `json:"objectKey"`
	} `json:"tasks"`
}

type adminFileUploadAuditTaskRequeueSuccessResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
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

	t.Run("requeue success english", func(t *testing.T) {
		taskID := ensureAdminFileUploadAuditTask(t, c, admin.Token)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/file-upload-audit/tasks/"+taskID+"/requeue",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("requeue file upload audit task request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
		}

		var payload adminFileUploadAuditTaskRequeueSuccessResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			t.Fatalf("decode requeue success response failed: %v", err)
		}
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Requeued successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})
}

func ensureAdminFileUploadAuditTask(t *testing.T, c *testutil.Client, token string) string {
	t.Helper()

	key := fmt.Sprintf("admin-i18n/audit-%d.txt", time.Now().UnixNano())
	uploadReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers/test/upload",
		token,
		map[string]any{
			"key":          key,
			"content":      "audit-task-source",
			"content_type": "text/plain",
		},
	)

	uploadResp, err := c.HTTP.Do(uploadReq)
	if err != nil {
		t.Fatalf("upload request failed: %v", err)
	}
	defer uploadResp.Body.Close()

	if uploadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(uploadResp.Body)
		t.Fatalf("unexpected upload status: want %d got %d body=%s", http.StatusOK, uploadResp.StatusCode, string(body))
	}

	var uploadPayload struct {
		Success bool `json:"success"`
	}
	if err := json.NewDecoder(uploadResp.Body).Decode(&uploadPayload); err != nil {
		t.Fatalf("decode upload response failed: %v", err)
	}
	if !uploadPayload.Success {
		t.Fatalf("expected upload success=true, got false")
	}

	listReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodGet,
		c.BaseURL+"/api/admin/file-upload-audit/tasks?keyword="+url.QueryEscape(key),
		token,
		nil,
	)

	listResp, err := c.HTTP.Do(listReq)
	if err != nil {
		t.Fatalf("list file upload audit tasks request failed: %v", err)
	}
	defer listResp.Body.Close()

	if listResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(listResp.Body)
		t.Fatalf("unexpected list status: want %d got %d body=%s", http.StatusOK, listResp.StatusCode, string(body))
	}

	var listPayload adminFileUploadAuditTaskListResponse
	if err := json.NewDecoder(listResp.Body).Decode(&listPayload); err != nil {
		t.Fatalf("decode file upload audit task list response failed: %v", err)
	}

	for _, task := range listPayload.Tasks {
		if task.ObjectKey == key {
			return task.ID
		}
	}

	t.Fatalf("file upload audit task not found for key: %s", key)
	return ""
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
