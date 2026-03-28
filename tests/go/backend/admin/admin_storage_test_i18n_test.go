package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type adminStorageTestUploadResponse struct {
	Success bool    `json:"success"`
	Url     *string `json:"url"`
	Message string  `json:"message"`
}

type adminStorageTestSignatureResponse struct {
	Success   bool           `json:"success"`
	Signature map[string]any `json:"signature"`
	Message   string         `json:"message"`
}

type adminStorageTestMultipartResponse struct {
	Success    bool    `json:"success"`
	Message    string  `json:"message"`
	Key        *string `json:"key"`
	SessionID  *string `json:"session_id"`
	PartSize   *int    `json:"part_size"`
	TotalParts *int    `json:"total_parts"`
}

type adminStorageTestDownloadResponse struct {
	Success bool    `json:"success"`
	Url     *string `json:"url"`
	Message string  `json:"message"`
}

func TestAdminStorageTestLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)
	admin := testutil.AdminLogin(t, c)

	t.Run("upload missing content english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload",
			admin.Token,
			map[string]any{
				"key": "admin-i18n/upload-missing-content.txt",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test upload request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestUploadResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Please provide file content or choose a file to upload." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("upload success english", func(t *testing.T) {
		key := uniqueAdminStorageTestKey("upload")
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload",
			admin.Token,
			map[string]any{
				"key":          key,
				"content":      "hello storage i18n",
				"content_type": "text/plain",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test upload request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestUploadResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Upload completed successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.Url == nil || *payload.Url == "" {
			t.Fatalf("expected upload url, got %+v", payload.Url)
		}
	})

	t.Run("upload signature key required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload/signature",
			admin.Token,
			map[string]any{
				"key": "   ",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test upload signature request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestSignatureResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "File path is required." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("upload signature success english", func(t *testing.T) {
		key := uniqueAdminStorageTestKey("signature")
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload/signature",
			admin.Token,
			map[string]any{
				"key":          key,
				"content_type": "text/plain",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("test upload signature request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestSignatureResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Direct upload signature generated successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.Signature == nil {
			t.Fatalf("expected signature payload, got nil")
		}
	})

	t.Run("multipart initiate key required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload/multipart/initiate",
			admin.Token,
			map[string]any{
				"key":       "   ",
				"file_size": 1024,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("multipart initiate request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestMultipartResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "File path is required." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("multipart initiate file size invalid english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload/multipart/initiate",
			admin.Token,
			map[string]any{
				"key":       uniqueAdminStorageTestKey("multipart-invalid"),
				"file_size": 0,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("multipart initiate request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestMultipartResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "file_size is required and must be greater than 0." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("multipart initiate success english", func(t *testing.T) {
		key := uniqueAdminStorageTestKey("multipart")
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/upload/multipart/initiate",
			admin.Token,
			map[string]any{
				"key":          key,
				"file_size":    6 * 1024 * 1024,
				"content_type": "application/octet-stream",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("multipart initiate request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestMultipartResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Multipart upload session initialized successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.SessionID == nil || *payload.SessionID == "" {
			t.Fatalf("expected session id, got %+v", payload.SessionID)
		}
	})

	t.Run("download url key required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/download-url",
			admin.Token,
			map[string]any{
				"key": "   ",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("download url request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestDownloadResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "File path (key) is required." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("download url success and cache english", func(t *testing.T) {
		key := ensureAdminStorageTestFileUploaded(t, c, admin.Token)

		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/download-url",
			admin.Token,
			map[string]any{
				"key":                key,
				"expires_in_seconds": 600,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("download url request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestDownloadResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "Download URL generated successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
		if payload.Url == nil || *payload.Url == "" {
			t.Fatalf("expected download url, got %+v", payload.Url)
		}

		cachedReq := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/download-url",
			admin.Token,
			map[string]any{
				"key":                key,
				"expires_in_seconds": 600,
			},
		)
		cachedReq.Header.Set("Accept-Language", "en-US")

		cachedResp, err := c.HTTP.Do(cachedReq)
		if err != nil {
			t.Fatalf("cached download url request failed: %v", err)
		}
		defer cachedResp.Body.Close()

		cachedPayload := decodeAdminStorageTestDownloadResponse(t, cachedResp, http.StatusOK)
		if !cachedPayload.Success {
			t.Fatalf("expected cached success=true, got false: %+v", cachedPayload)
		}
		if cachedPayload.Message != "Download URL generated successfully (cached)." {
			t.Fatalf("unexpected cached message: %q", cachedPayload.Message)
		}
		if cachedPayload.Url == nil || *cachedPayload.Url == "" {
			t.Fatalf("expected cached download url, got %+v", cachedPayload.Url)
		}
	})
}

func ensureAdminStorageTestFileUploaded(
	t *testing.T,
	c *testutil.Client,
	token string,
) string {
	t.Helper()

	key := uniqueAdminStorageTestKey("download")
	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers/test/upload",
		token,
		map[string]any{
			"key":          key,
			"content":      "download-url-source",
			"content_type": "text/plain",
		},
	)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("pre-upload request failed: %v", err)
	}
	defer resp.Body.Close()

	payload := decodeAdminStorageTestUploadResponse(t, resp, http.StatusOK)
	if !payload.Success {
		t.Fatalf("expected pre-upload success=true, got false: %+v", payload)
	}

	return key
}

func uniqueAdminStorageTestKey(prefix string) string {
	return fmt.Sprintf("admin-i18n/%s-%d.txt", prefix, time.Now().UnixNano())
}

func decodeAdminStorageTestUploadResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestUploadResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestUploadResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test upload response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestSignatureResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestSignatureResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestSignatureResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test signature response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestMultipartResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestMultipartResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestMultipartResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test multipart response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestDownloadResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestDownloadResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestDownloadResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test download response failed: %v", err)
	}

	return payload
}
