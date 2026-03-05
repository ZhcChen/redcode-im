package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type cleanupSuccessResponse struct {
	Success      bool   `json:"success"`
	DeletedCount uint64 `json:"deletedCount"`
	Message      string `json:"message"`
}

type apiErrorResponse struct {
	Code    int     `json:"code"`
	Message string  `json:"message"`
	Details *string `json:"details"`
}

func TestAdminLogCleanupContract_OKAndValidationError(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	testCases := []struct {
		name string
		path string
	}{
		{name: "system logs cleanup", path: "/api/admin/logs/cleanup"},
		{name: "push logs cleanup", path: "/api/admin/push/logs/cleanup"},
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
			if payload.Message == "" || !strings.Contains(payload.Message, "最近 2 天") {
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
			if !strings.Contains(payload.Message, "保留天数必须大于 0") {
				t.Fatalf("cleanup error message mismatch: %q", payload.Message)
			}
		})
	}
}
