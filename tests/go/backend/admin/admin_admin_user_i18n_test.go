package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminAdminUserAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

type adminAdminUserInfo struct {
	ID string `json:"id"`
}

type adminOperationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdminAdminUserLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("list invalid status english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/admin-users?status=paused",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("list admin users request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.admin_user_status_invalid",
			"Status parameter is invalid.",
			nil,
		)
	})

	t.Run("create required fields missing english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/admin-users",
			admin.Token,
			map[string]any{
				"username": "   ",
				"email":    "   ",
				"password": "   ",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create admin user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.admin_user_required_fields_missing",
			"Username, email, and password are required.",
			nil,
		)
	})

	t.Run("create duplicate username chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/admin-users",
			admin.Token,
			map[string]any{
				"username": "admin",
				"email":    "admin-duplicate@example.com",
				"password": "admin123",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create admin user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.admin_user_username_already_exists",
			"用户名已存在",
			nil,
		)
	})

	t.Run("update invalid admin user id chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/admin-users/not-a-uuid/status",
			admin.Token,
			map[string]any{"status": "active"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update admin user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.admin_user_id_invalid",
			"无效的管理员用户ID",
			nil,
		)
	})

	t.Run("update invalid status value english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/admin-users/550e8400-e29b-41d4-a716-446655440030/status",
			admin.Token,
			map[string]any{"status": "paused"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update admin user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.admin_user_status_value_invalid",
			"Admin user status value is invalid.",
			nil,
		)
	})

	t.Run("update admin user not found chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/admin-users/550e8400-e29b-41d4-a716-446655440031/status",
			admin.Token,
			map[string]any{"status": "active"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update admin user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.admin_user_not_found",
			"管理员用户不存在",
			nil,
		)
	})

	t.Run("update admin user status success english", func(t *testing.T) {
		createdUserID := createAdminUserForLocalizedTests(
			t,
			c,
			admin.Token,
			testutil.UniqueUsername("adminuser"),
		)

		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/admin-users/"+createdUserID+"/status",
			admin.Token,
			map[string]any{"status": "inactive"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update admin user status request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
		}

		var payload adminOperationResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			t.Fatalf("decode admin operation response failed: %v", err)
		}

		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Admin user status updated successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})
}

func assertLocalizedAdminAdminUserError(
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

	var payload adminAdminUserAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized admin admin-user error response failed: %v", err)
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

func createAdminUserForLocalizedTests(
	t *testing.T,
	c *testutil.Client,
	token string,
	username string,
) string {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/admin-users",
		token,
		map[string]any{
			"username": username,
			"email":    username + "@example.com",
			"password": "admin123",
		},
	)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create admin user request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
	}

	var payload adminAdminUserInfo
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin user info failed: %v", err)
	}
	if payload.ID == "" {
		t.Fatalf("created admin user id is empty")
	}

	return payload.ID
}
