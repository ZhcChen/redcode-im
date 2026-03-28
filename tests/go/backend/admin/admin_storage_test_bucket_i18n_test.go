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

type adminStorageTestListBucketsResponse struct {
	Success bool             `json:"success"`
	Buckets []map[string]any `json:"buckets"`
	Message string           `json:"message"`
}

type adminStorageTestCreateBucketResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdminStorageTestBucketLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)
	admin := testutil.AdminLogin(t, c)
	inactiveProviderID := createInactiveStorageProviderForBucketTests(t, c, admin.Token)

	t.Run("list buckets inactive provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/buckets",
			admin.Token,
			map[string]any{
				"provider_id": inactiveProviderID,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("list buckets request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestListBucketsResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if len(payload.Buckets) != 0 {
			t.Fatalf("expected empty buckets, got %+v", payload.Buckets)
		}
		if payload.Message != "Storage provider is inactive." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("create bucket name required english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/buckets/create",
			admin.Token,
			map[string]any{
				"bucket_name": "   ",
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create bucket request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCreateBucketResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Bucket name is required." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("create bucket inactive provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/buckets/create",
			admin.Token,
			map[string]any{
				"provider_id": inactiveProviderID,
				"bucket_name": fmt.Sprintf("codex-i18n-%d", time.Now().UnixMilli()),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("create bucket request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCreateBucketResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Storage provider is inactive." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})
}

func createInactiveStorageProviderForBucketTests(
	t *testing.T,
	c *testutil.Client,
	token string,
) string {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers",
		token,
		map[string]any{
			"provider_type": "tencent_cos",
			"name":          fmt.Sprintf("inactive-bucket-provider-%d", time.Now().UnixNano()),
			"secret_id":     "mock-secret-id",
			"secret_key":    "mock-secret-key",
			"region":        "ap-shanghai",
			"endpoint":      "external-mock:19080",
			"bucket_name":   "mock-bucket",
			"is_active":     false,
			"is_default":    false,
			"description":   "inactive provider for bucket i18n tests",
		},
	)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create inactive provider request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
	}

	var payload struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode inactive provider response failed: %v", err)
	}
	if payload.ID == "" {
		t.Fatalf("inactive provider id is empty")
	}

	return payload.ID
}

func decodeAdminStorageTestListBucketsResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestListBucketsResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestListBucketsResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test list buckets response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestCreateBucketResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestCreateBucketResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestCreateBucketResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test create bucket response failed: %v", err)
	}

	return payload
}
