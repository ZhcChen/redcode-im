package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type cleanupSuccessResponse struct {
	Success      bool   `json:"success"`
	DeletedCount uint64 `json:"deletedCount"`
	Message      string `json:"message"`
}

type apiErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestAdminLogCleanupContract_OKAndValidationError(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	testCases := []struct {
		name           string
		path           string
		successLocale  string
		successMessage func(uint64) string
		errorLocale    string
		errorMessage   string
	}{
		{
			name:          "system logs cleanup",
			path:          "/api/admin/logs/cleanup",
			successLocale: "en-US",
			successMessage: func(deletedCount uint64) string {
				return fmt.Sprintf(
					"Deleted %d logs successfully. Retained logs from the last 2 days.",
					deletedCount,
				)
			},
			errorLocale:  "en-US",
			errorMessage: "Retention days must be greater than 0.",
		},
		{
			name:          "push logs cleanup",
			path:          "/api/admin/push/logs/cleanup",
			successLocale: "zh-CN",
			successMessage: func(deletedCount uint64) string {
				return fmt.Sprintf(
					"成功删除 %d 条 push 日志，保留最近 2 天的日志",
					deletedCount,
				)
			},
			errorLocale:  "zh-CN",
			errorMessage: "保留天数必须大于 0",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name+" success", func(t *testing.T) {
			req := testutil.NewAuthedJSONRequest(
				t,
				http.MethodPost,
				c.BaseURL+tc.path,
				admin.Token,
				map[string]any{"retentionDays": 2},
			)
			req.Header.Set("Accept-Language", tc.successLocale)
			resp, err := c.HTTP.Do(req)
			if err != nil {
				t.Fatalf("cleanup request failed: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				body, _ := io.ReadAll(resp.Body)
				t.Fatalf("cleanup expect 200, got %d: %s", resp.StatusCode, string(body))
			}

			var payload cleanupSuccessResponse
			if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
				t.Fatalf("decode cleanup response failed: %v", err)
			}
			if !payload.Success {
				t.Fatalf("expect success=true, got false: %+v", payload)
			}
			if payload.Message != tc.successMessage(payload.DeletedCount) {
				t.Fatalf("cleanup response message invalid: %q", payload.Message)
			}
		})

		t.Run(tc.name+" invalid retention days", func(t *testing.T) {
			req := testutil.NewAuthedJSONRequest(
				t,
				http.MethodPost,
				c.BaseURL+tc.path,
				admin.Token,
				map[string]any{"retentionDays": 0},
			)
			req.Header.Set("Accept-Language", tc.errorLocale)
			resp, err := c.HTTP.Do(req)
			if err != nil {
				t.Fatalf("cleanup request failed: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusBadRequest {
				body, _ := io.ReadAll(resp.Body)
				t.Fatalf("cleanup expect 400, got %d: %s", resp.StatusCode, string(body))
			}

			var payload apiErrorResponse
			if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
				t.Fatalf("decode cleanup error response failed: %v", err)
			}
			if payload.Code != 42201 {
				t.Fatalf("cleanup error code mismatch: expect 42201, got %d", payload.Code)
			}
			if payload.MessageKey != "admin.log_cleanup_retention_days_invalid" {
				t.Fatalf("cleanup error message_key mismatch: %q", payload.MessageKey)
			}
			if payload.Message != tc.errorMessage {
				t.Fatalf("cleanup error message mismatch: %q", payload.Message)
			}
			if payload.MessageParams != nil {
				t.Fatalf("cleanup error message_params mismatch: %+v", payload.MessageParams)
			}
			if payload.Details != nil {
				t.Fatalf("cleanup error details mismatch: %q", *payload.Details)
			}
		})
	}
}
