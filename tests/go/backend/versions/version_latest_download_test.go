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

func TestLatestVersionAndDownloadURL_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	suffix := strconv.FormatInt(time.Now().UnixNano()%1_000_000, 10)
	channel := "it-" + suffix
	versionStr := "1.0." + suffix
	downloadURL := "https://example.com/download/" + suffix + ".apk"

	createPayload := map[string]any{
		"platform":      "android",
		"version":       versionStr,
		"build_number":  1000,
		"channel":       channel,
		"download_key":  "",
		"download_url":  downloadURL,
		"app_store_url": "",
		"file_size":     12345,
		"checksum":      "abc123",
		"signature":     "sig",
		"release_notes": "integration test",
		"mandatory":     false,
		"is_active":     true,
	}
	createReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/api/admin/app-versions", admin.Token, createPayload)
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		t.Fatalf("create app version failed: %v", err)
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		t.Fatalf("create app version expect 200, got %d: %s", createResp.StatusCode, string(body))
	}

	latestReq := c.BaseURL + "/versions/latest?platform=android&channel=" + url.QueryEscape(channel)
	latestResp, err := c.HTTP.Get(latestReq)
	if err != nil {
		t.Fatalf("get latest version failed: %v", err)
	}
	defer latestResp.Body.Close()
	if latestResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(latestResp.Body)
		t.Fatalf("latest version expect 200, got %d: %s", latestResp.StatusCode, string(body))
	}

	var latestResult struct {
		HasUpdate bool `json:"has_update"`
		Version   *struct {
			Version string `json:"version"`
			Channel string `json:"channel"`
		} `json:"version"`
	}
	if err := json.NewDecoder(latestResp.Body).Decode(&latestResult); err != nil {
		t.Fatalf("decode latest version response failed: %v", err)
	}
	if latestResult.Version == nil {
		t.Fatalf("latest version is nil")
	}
	if latestResult.Version.Version != versionStr {
		t.Fatalf("expect version %s, got %s", versionStr, latestResult.Version.Version)
	}
	if latestResult.Version.Channel != channel {
		t.Fatalf("expect channel %s, got %s", channel, latestResult.Version.Channel)
	}

	downloadReq := c.BaseURL + "/versions/latest/download-url?platform=android&channel=" + url.QueryEscape(channel)
	downloadResp, err := c.HTTP.Get(downloadReq)
	if err != nil {
		t.Fatalf("get latest download url failed: %v", err)
	}
	defer downloadResp.Body.Close()
	if downloadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(downloadResp.Body)
		t.Fatalf("latest download url expect 200, got %d: %s", downloadResp.StatusCode, string(body))
	}

	var downloadResult struct {
		Success     bool   `json:"success"`
		DownloadURL string `json:"download_url"`
	}
	if err := json.NewDecoder(downloadResp.Body).Decode(&downloadResult); err != nil {
		t.Fatalf("decode download url response failed: %v", err)
	}
	if !downloadResult.Success {
		t.Fatalf("download response success=false")
	}
	if downloadResult.DownloadURL != downloadURL {
		t.Fatalf("expect download_url %s, got %s", downloadURL, downloadResult.DownloadURL)
	}
}

func TestLatestDownloadURL_InvalidPlatform_Localized(t *testing.T) {
	c := testutil.NewClient()

	req, err := http.NewRequest(
		http.MethodGet,
		c.BaseURL+"/versions/latest/download-url?platform=bad&channel=stable",
		nil,
	)
	if err != nil {
		t.Fatalf("build latest download url request failed: %v", err)
	}
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("execute latest download url request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedVersionError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"version.platform_unsupported",
		"Unsupported platform: bad. Supported platforms: windows, macos, ios, android, linux.",
		map[string]string{
			"platform":            "bad",
			"supported_platforms": "windows, macos, ios, android, linux",
		},
	)
}
