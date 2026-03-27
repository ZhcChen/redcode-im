package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminGeolocationAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

type adminIpGeolocationStatusResponse struct {
	Enabled     bool   `json:"enabled"`
	Description string `json:"description"`
}

func TestAdminGeolocationLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("test geolocation api empty ip english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/test-geolocation-api",
			admin.Token,
			map[string]any{
				"ip_address": "   ",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test geolocation api request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminGeolocationError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.geolocation_ip_required",
			"IP address is required.",
			nil,
		)
	})

	t.Run("test geolocation api invalid ip chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/test-geolocation-api",
			admin.Token,
			map[string]any{
				"ip_address": "127.0.0",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test geolocation api request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminGeolocationError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.geolocation_ip_invalid",
			"IP地址格式无效",
			nil,
		)
	})

	t.Run("get ip geolocation status english description", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/ip-geolocation/enabled",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get ip geolocation status request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
		}

		var payload adminIpGeolocationStatusResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			t.Fatalf("decode ip geolocation status response failed: %v", err)
		}

		if payload.Description != "Controls whether user IP geolocation resolution is enabled for admin analytics." {
			t.Fatalf("unexpected description: %q", payload.Description)
		}
	})

	t.Run("patch ip geolocation status chinese description", func(t *testing.T) {
		getReq := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/ip-geolocation/enabled",
			admin.Token,
			nil,
		)
		getResp, err := c.HTTP.Do(getReq)
		if err != nil {
			t.Fatalf("get ip geolocation status request failed: %v", err)
		}
		defer getResp.Body.Close()

		if getResp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(getResp.Body)
			t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, getResp.StatusCode, string(body))
		}

		var current adminIpGeolocationStatusResponse
		if err := json.NewDecoder(getResp.Body).Decode(&current); err != nil {
			t.Fatalf("decode current ip geolocation status response failed: %v", err)
		}

		patchReq := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPatch,
			c.BaseURL+"/api/admin/ip-geolocation/enabled",
			admin.Token,
			map[string]any{
				"enabled": current.Enabled,
			},
		)
		patchReq.Header.Set("Accept-Language", "zh-CN")

		patchResp, err := c.HTTP.Do(patchReq)
		if err != nil {
			t.Fatalf("patch ip geolocation status request failed: %v", err)
		}
		defer patchResp.Body.Close()

		if patchResp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(patchResp.Body)
			t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, patchResp.StatusCode, string(body))
		}

		var payload adminIpGeolocationStatusResponse
		if err := json.NewDecoder(patchResp.Body).Decode(&payload); err != nil {
			t.Fatalf("decode patched ip geolocation status response failed: %v", err)
		}

		if payload.Description != "控制是否启用用户IP地理位置解析功能，用于管理员数据统计" {
			t.Fatalf("unexpected description: %q", payload.Description)
		}
	})
}

func assertLocalizedAdminGeolocationError(
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

	var payload adminGeolocationAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized admin geolocation error response failed: %v", err)
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
