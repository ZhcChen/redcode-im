package versions_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type versionAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestLatestVersionPlatformRequired_Localized(t *testing.T) {
	c := testutil.NewClient()

	req, err := http.NewRequest(http.MethodGet, c.BaseURL+"/versions/latest?platform=&channel=stable", nil)
	if err != nil {
		t.Fatalf("build latest version request failed: %v", err)
	}
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("latest version request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedVersionError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"version.platform_required",
		"platform is required.",
		nil,
	)
}

func TestDownloadLatestVersionNoAvailableRelease_Localized(t *testing.T) {
	c := testutil.NewClient()

	req, err := http.NewRequest(
		http.MethodGet,
		c.BaseURL+"/versions/latest/download-url?platform=android&channel="+url.QueryEscape("missing-"+strconv.FormatInt(time.Now().UnixNano(), 10)),
		nil,
	)
	if err != nil {
		t.Fatalf("build latest download request failed: %v", err)
	}
	req.Header.Set("Accept-Language", "zh-CN")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("latest download request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedVersionError(
		t,
		resp,
		http.StatusNotFound,
		40401,
		"version.no_available_release",
		"暂无可用版本",
		nil,
	)
}

func TestDownloadLatestVersionMissingDownloadConfig_Localized(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	suffix := strconv.FormatInt(time.Now().UnixNano()%1_000_000, 10)
	channel := "store-only-" + suffix
	versionStr := "2.0." + suffix

	createReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/app-versions",
		admin.Token,
		map[string]any{
			"platform":      "android",
			"version":       versionStr,
			"build_number":  2000,
			"channel":       channel,
			"download_key":  "",
			"download_url":  "",
			"app_store_url": "https://example.com/store/" + suffix,
			"file_size":     54321,
			"checksum":      "store-only-checksum",
			"signature":     "store-only-signature",
			"release_notes": "version i18n contract test",
			"mandatory":     false,
			"is_active":     true,
		},
	)
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		t.Fatalf("create app version failed: %v", err)
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		t.Fatalf("create app version expect 200, got %d: %s", createResp.StatusCode, string(body))
	}

	req, err := http.NewRequest(
		http.MethodGet,
		c.BaseURL+"/versions/latest/download-url?platform=android&channel="+url.QueryEscape(channel),
		nil,
	)
	if err != nil {
		t.Fatalf("build latest download request failed: %v", err)
	}
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("latest download request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedVersionError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"version.download_info_missing",
		"This version does not have a package download configured (download_key/download_url).",
		nil,
	)
}

func assertLocalizedVersionError(
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

	var payload versionAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized version error response failed: %v", err)
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
