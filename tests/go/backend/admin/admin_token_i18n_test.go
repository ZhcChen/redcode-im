package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminTokenAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

type adminTokenInfo struct {
	ID string `json:"id"`
}

func TestAdminIpInfoTokenCreateLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("name required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/ipinfo-tokens",
			admin.Token,
			map[string]any{
				"name":  "   ",
				"token": "ipinfo-token-value",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.ipinfo_token_name_required",
			"Token name is required.",
			nil,
		)
	})

	t.Run("token value required chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/ipinfo-tokens",
			admin.Token,
			map[string]any{
				"name":  testutil.UniqueUsername("ipinfo-name"),
				"token": "   ",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.ipinfo_token_value_required",
			"Token值不能为空",
			nil,
		)
	})

	t.Run("duplicate token name english", func(t *testing.T) {
		name := testutil.UniqueUsername("ipinfo-dup")
		createAdminIpInfoToken(t, c, admin.Token, name, uniqueIPInfoTokenValue())

		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/ipinfo-tokens",
			admin.Token,
			map[string]any{
				"name":  name,
				"token": "ipinfo-token-value-b",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("duplicate ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusConflict,
			40901,
			"admin.ipinfo_token_name_already_exists",
			"Token name already exists.",
			nil,
		)
	})
}

func TestAdminIpInfoTokenMutationLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("update invalid token id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/ipinfo-tokens/not-a-uuid",
			admin.Token,
			map[string]any{"name": "updated-name"},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.ipinfo_token_id_invalid",
			"Token ID is invalid.",
			nil,
		)
	})

	t.Run("update requires at least one field chinese", func(t *testing.T) {
		tokenID := createAdminIpInfoToken(
			t,
			c,
			admin.Token,
			testutil.UniqueUsername("ipinfo-update"),
			uniqueIPInfoTokenValue(),
		)

		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/ipinfo-tokens/"+tokenID,
			admin.Token,
			map[string]any{},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("update ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.ipinfo_token_update_fields_required",
			"没有需要更新的字段",
			nil,
		)
	})

	t.Run("delete token not found english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodDelete,
			c.BaseURL+"/api/admin/ipinfo-tokens/550e8400-e29b-41d4-a716-446655440000",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.ipinfo_token_not_found",
			"Token was not found.",
			nil,
		)
	})

	t.Run("reset invalid token id chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/ipinfo-tokens/not-a-uuid/reset",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("reset ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.ipinfo_token_id_invalid",
			"无效的Token ID",
			nil,
		)
	})

	t.Run("reset token not found english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/ipinfo-tokens/550e8400-e29b-41d4-a716-446655440001/reset",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("reset ipinfo token request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminTokenError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.ipinfo_token_not_found",
			"Token was not found.",
			nil,
		)
	})
}

func createAdminIpInfoToken(t *testing.T, c *testutil.Client, token, name, value string) string {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/ipinfo-tokens",
		token,
		map[string]any{
			"name":  name,
			"token": value,
		},
	)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("seed ipinfo token request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("seed ipinfo token expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload adminTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode seeded ipinfo token failed: %v", err)
	}
	if payload.ID == "" {
		t.Fatalf("seeded ipinfo token id is empty")
	}

	return payload.ID
}

func uniqueIPInfoTokenValue() string {
	return testutil.UniqueUsername("ipinfo-token-value")
}

func assertLocalizedAdminTokenError(
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

	var payload adminTokenAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized admin token error response failed: %v", err)
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
