package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminStorageProviderAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestAdminStorageProviderCreateLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("name required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers",
			admin.Token,
			map[string]any{
				"provider_type": "tencent_cos",
				"name":          "   ",
				"secret_id":     "mock-secret-id",
				"secret_key":    "mock-secret-key",
				"region":        "ap-shanghai",
				"endpoint":      "external-mock:19080",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create storage provider request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminStorageProviderError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.storage_provider_name_required",
			"Storage provider name is required.",
			nil,
		)
	})

	t.Run("unsupported provider type chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers",
			admin.Token,
			map[string]any{
				"provider_type": "foo-storage",
				"name":          "mock-provider",
				"secret_id":     "mock-secret-id",
				"secret_key":    "mock-secret-key",
				"region":        "ap-shanghai",
				"endpoint":      "external-mock:19080",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create storage provider request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminStorageProviderError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.storage_provider_type_unsupported",
			"不支持的提供商类型: foo-storage",
			map[string]string{
				"provider_type": "foo-storage",
			},
		)
	})
}

func TestAdminStorageProviderMutationLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("update invalid provider id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/storage-providers/not-a-uuid",
			admin.Token,
			map[string]any{"name": "updated-provider"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update storage provider request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminStorageProviderError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.storage_provider_id_invalid",
			"Storage provider ID is invalid.",
			nil,
		)
	})

	t.Run("delete storage provider not found chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/storage-providers/550e8400-e29b-41d4-a716-446655440010",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete storage provider request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminStorageProviderError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.storage_provider_not_found",
			"提供商配置不存在",
			nil,
		)
	})
}

func assertLocalizedAdminStorageProviderError(
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

	var payload adminStorageProviderAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized admin storage provider error response failed: %v", err)
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
