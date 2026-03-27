package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminFileOperationResponse struct {
	Success      bool   `json:"success"`
	Message      string `json:"message"`
	DeletedCount *int   `json:"deleted_count"`
}

func TestAdminRoleAndFileOperationLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("create role name required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/roles",
			admin.Token,
			map[string]any{
				"name":           "   ",
				"code":           "ops",
				"permission_ids": []string{},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"Role name is required.",
		)
	})

	t.Run("create role code required chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/roles",
			admin.Token,
			map[string]any{
				"name":           "运营角色",
				"code":           "   ",
				"permission_ids": []string{},
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"角色代码不能为空",
		)
	})

	t.Run("create role success english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/roles",
			admin.Token,
			map[string]any{
				"name":           "Operations",
				"code":           "ops",
				"permission_ids": []string{},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"Role created successfully.",
		)
	})

	t.Run("update role system role chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/roles/1",
			admin.Token,
			map[string]any{"name": "更新角色"},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"系统角色不允许修改",
		)
	})

	t.Run("update role success english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/roles/2",
			admin.Token,
			map[string]any{"name": "Updated role"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"Role updated successfully.",
		)
	})

	t.Run("delete role system role chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/roles/1",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"系统角色不允许删除",
		)
	})

	t.Run("delete role success english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/roles/2",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete role request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"Role deleted successfully.",
		)
	})

	t.Run("delete file success english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/files/file-123",
			admin.Token,
			map[string]any{},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete file request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminFileOperationResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "File deleted successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.DeletedCount == nil || *payload.DeletedCount != 1 {
			t.Fatalf("unexpected deleted count: %+v", payload.DeletedCount)
		}
	})

	t.Run("batch delete files empty list chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/files/batch-delete",
			admin.Token,
			[]string{},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("batch delete files request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminFileOperationResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "请提供要删除的文件ID列表" {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.DeletedCount == nil || *payload.DeletedCount != 0 {
			t.Fatalf("unexpected deleted count: %+v", payload.DeletedCount)
		}
	})

	t.Run("batch delete files success english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/files/batch-delete",
			admin.Token,
			[]string{"file-1", "file-2"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("batch delete files request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminFileOperationResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Deleted 2 files successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.DeletedCount == nil || *payload.DeletedCount != 2 {
			t.Fatalf("unexpected deleted count: %+v", payload.DeletedCount)
		}
	})
}

func decodeAdminFileOperationResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminFileOperationResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminFileOperationResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin file operation response failed: %v", err)
	}

	return payload
}

func assertAdminOperationResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
	wantSuccess bool,
	wantMessage string,
) {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminOperationResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin operation response failed: %v", err)
	}

	if payload.Success != wantSuccess {
		t.Fatalf("unexpected success: want %v got %v", wantSuccess, payload.Success)
	}
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: want %q got %q", wantMessage, payload.Message)
	}
}
