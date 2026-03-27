package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminUserOperationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdminUserOperationLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("create user username too short english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/users",
			admin.Token,
			map[string]any{
				"username": "ab",
				"email":    "short-user@example.com",
				"password": "pass123456",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"Username must be at least 3 characters long.",
		)
	})

	t.Run("create user duplicate email chinese", func(t *testing.T) {
		username := testutil.UniqueUsername("dupemail")
		testutil.RegisterUser(t, c, username, "pass123456")

		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/users",
			admin.Token,
			map[string]any{
				"username": testutil.UniqueUsername("newuser"),
				"email":    username + "@example.com",
				"password": "pass123456",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"邮箱已被注册",
		)
	})

	t.Run("create user success english", func(t *testing.T) {
		username := testutil.UniqueUsername("created")
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/users",
			admin.Token,
			map[string]any{
				"username": username,
				"email":    username + "@example.com",
				"password": "pass123456",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create user request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminUserOperationResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if !strings.HasPrefix(payload.Message, "User created successfully. ID: ") {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("update user no fields provided english", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/"+user.ID,
			admin.Token,
			map[string]any{},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"No fields were provided to update.",
		)
	})

	t.Run("update user invalid status chinese", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/"+user.ID,
			admin.Token,
			map[string]any{"status": "paused"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"无效的用户状态",
		)
	})

	t.Run("update user success chinese", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/"+user.ID,
			admin.Token,
			map[string]any{"nickname": "已更新昵称"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"用户信息更新成功",
		)
	})

	t.Run("reset password too short english", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/users/"+user.ID+"/password/reset",
			admin.Token,
			map[string]any{"new_password": "12345"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("reset password request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"Password must be at least 6 characters long.",
		)
	})

	t.Run("reset password success chinese", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/users/"+user.ID+"/password/reset",
			admin.Token,
			map[string]any{"new_password": "newpass123"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("reset password request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"密码重置成功",
		)
	})

	t.Run("delete user success english", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/users/"+user.ID,
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete user request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"User deleted successfully.",
		)
	})

	t.Run("update user status invalid user id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/not-a-uuid/status",
			admin.Token,
			map[string]any{"status": "active"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.user_id_invalid",
			"User ID is invalid.",
			nil,
		)
	})

	t.Run("update user status invalid status chinese", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/"+user.ID+"/status",
			admin.Token,
			map[string]any{"status": "paused"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.user_status_invalid",
			"无效的用户状态",
			nil,
		)
	})

	t.Run("update user status success english", func(t *testing.T) {
		user := createRegularUserForAdminOperationTests(t, c)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/users/"+user.ID+"/status",
			admin.Token,
			map[string]any{"status": "inactive"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update user status request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminUserOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"User status updated successfully.",
		)
	})
}

func decodeAdminUserOperationResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminUserOperationResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminUserOperationResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin user operation response failed: %v", err)
	}

	return payload
}

func assertAdminUserOperationResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
	wantSuccess bool,
	wantMessage string,
) {
	t.Helper()

	payload := decodeAdminUserOperationResponse(t, resp, wantStatus)
	if payload.Success != wantSuccess {
		t.Fatalf("unexpected success: want %v got %v", wantSuccess, payload.Success)
	}
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: want %q got %q", wantMessage, payload.Message)
	}
}

func createRegularUserForAdminOperationTests(t *testing.T, c *testutil.Client) testutil.UserInfo {
	t.Helper()

	username := testutil.UniqueUsername("regular")
	password := "pass123456"
	return testutil.RegisterUser(t, c, username, password)
}
