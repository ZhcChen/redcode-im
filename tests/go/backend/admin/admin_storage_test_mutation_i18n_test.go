package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type adminStorageTestDeleteResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type adminStorageTestExistsResponse struct {
	Success bool   `json:"success"`
	Exists  bool   `json:"exists"`
	Message string `json:"message"`
}

type adminStorageTestCorsSetResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type adminStorageTestCorsGetResponse struct {
	Success bool             `json:"success"`
	Message string           `json:"message"`
	Rules   []map[string]any `json:"rules"`
}

func TestAdminStorageTestMutationLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)
	admin := testutil.AdminLogin(t, c)
	unsupportedProviderID := createStorageProviderForMutationFallbackTests(
		t,
		c,
		admin.Token,
		"aliyun_oss",
		true,
		"mock-unsupported-endpoint:19080",
		nil,
	)
	brokenTencentProviderID := createStorageProviderForMutationFallbackTests(
		t,
		c,
		admin.Token,
		"tencent_cos",
		true,
		"broken-endpoint.invalid:19080",
		ptrString("mock-bucket"),
	)

	t.Run("delete success english", func(t *testing.T) {
		key := ensureAdminStorageTestFileUploaded(t, c, admin.Token)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/delete",
			admin.Token,
			map[string]any{
				"key": key,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestDeleteResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Message != "File deleted successfully." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("delete unsupported provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/delete",
			admin.Token,
			map[string]any{
				"provider_id": unsupportedProviderID,
				"key":         uniqueAdminStorageTestKey("delete-unsupported"),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestDeleteResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Unsupported storage provider type: aliyun_oss." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("delete failure english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/delete",
			admin.Token,
			map[string]any{
				"provider_id": brokenTencentProviderID,
				"key":         uniqueAdminStorageTestKey("delete-failure"),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("delete request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestDeleteResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if !strings.HasPrefix(payload.Message, "Delete failed: ") {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("exists true english", func(t *testing.T) {
		key := ensureAdminStorageTestFileUploaded(t, c, admin.Token)
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/exists",
			admin.Token,
			map[string]any{
				"key": key,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("exists request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestExistsResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if !payload.Exists {
			t.Fatalf("expected exists=true, got false: %+v", payload)
		}
		if payload.Message != "File exists." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("exists false english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/exists",
			admin.Token,
			map[string]any{
				"key": uniqueAdminStorageTestKey("missing"),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("exists request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestExistsResponse(t, resp, http.StatusOK)
		if !payload.Success {
			t.Fatalf("expected success=true, got false: %+v", payload)
		}
		if payload.Exists {
			t.Fatalf("expected exists=false, got true: %+v", payload)
		}
		if payload.Message != "File does not exist." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("exists unsupported provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/exists",
			admin.Token,
			map[string]any{
				"provider_id": unsupportedProviderID,
				"key":         uniqueAdminStorageTestKey("exists-unsupported"),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("exists request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestExistsResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Exists {
			t.Fatalf("expected exists=false, got true: %+v", payload)
		}
		if payload.Message != "Unsupported storage provider type: aliyun_oss." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("exists failure english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/exists",
			admin.Token,
			map[string]any{
				"provider_id": brokenTencentProviderID,
				"key":         uniqueAdminStorageTestKey("exists-failure"),
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("exists request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestExistsResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Exists {
			t.Fatalf("expected exists=false, got true: %+v", payload)
		}
		if !strings.HasPrefix(payload.Message, "Failed to check file existence: ") {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("set cors empty rules english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors",
			admin.Token,
			map[string]any{
				"rules": []map[string]any{},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("set cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsSetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Please provide at least one CORS rule." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("set cors invalid method english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors",
			admin.Token,
			map[string]any{
				"rules": []map[string]any{
					{
						"allowed_origins": []string{"*"},
						"allowed_methods": []string{"TRACE"},
					},
				},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("set cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsSetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Unsupported CORS method: TRACE. COS only allows GET/PUT/POST/DELETE/HEAD." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("set cors unsupported provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors",
			admin.Token,
			map[string]any{
				"provider_id": unsupportedProviderID,
				"rules": []map[string]any{
					{
						"allowed_origins": []string{"*"},
						"allowed_methods": []string{"GET"},
					},
				},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("set cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsSetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if payload.Message != "Unsupported storage provider type: aliyun_oss." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("set cors failure english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors",
			admin.Token,
			map[string]any{
				"provider_id": brokenTencentProviderID,
				"rules": []map[string]any{
					{
						"allowed_origins": []string{"https://admin.example.com"},
						"allowed_methods": []string{"GET"},
					},
				},
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("set cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsSetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if !strings.HasPrefix(payload.Message, "Failed to update CORS rules: ") {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("set and get cors success english", func(t *testing.T) {
		setReq := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors",
			admin.Token,
			map[string]any{
				"rules": []map[string]any{
					{
						"allowed_origins": []string{"https://admin.example.com"},
						"allowed_methods": []string{"GET", "PUT"},
						"allowed_headers": []string{"*"},
						"expose_headers":  []string{"ETag"},
						"max_age_seconds": 600,
					},
				},
			},
		)
		setReq.Header.Set("Accept-Language", "en-US")

		setResp, err := c.HTTP.Do(setReq)
		if err != nil {
			t.Fatalf("set cors request failed: %v", err)
		}
		defer setResp.Body.Close()

		setPayload := decodeAdminStorageTestCorsSetResponse(t, setResp, http.StatusOK)
		if !setPayload.Success {
			t.Fatalf("expected set success=true, got false: %+v", setPayload)
		}
		if setPayload.Message != "CORS rules updated successfully." {
			t.Fatalf("unexpected set message: %q", setPayload.Message)
		}

		getReq := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors/list",
			admin.Token,
			map[string]any{},
		)
		getReq.Header.Set("Accept-Language", "en-US")

		getResp, err := c.HTTP.Do(getReq)
		if err != nil {
			t.Fatalf("get cors request failed: %v", err)
		}
		defer getResp.Body.Close()

		getPayload := decodeAdminStorageTestCorsGetResponse(t, getResp, http.StatusOK)
		if !getPayload.Success {
			t.Fatalf("expected get success=true, got false: %+v", getPayload)
		}
		if getPayload.Message != "CORS rules fetched successfully." {
			t.Fatalf("unexpected get message: %q", getPayload.Message)
		}
		if len(getPayload.Rules) == 0 {
			t.Fatalf("expected non-empty cors rules, got %+v", getPayload.Rules)
		}
	})

	t.Run("get cors unsupported provider english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors/list",
			admin.Token,
			map[string]any{
				"provider_id": unsupportedProviderID,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsGetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if len(payload.Rules) != 0 {
			t.Fatalf("expected empty rules, got %+v", payload.Rules)
		}
		if payload.Message != "Unsupported storage provider type: aliyun_oss." {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})

	t.Run("get cors failure english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/storage-providers/test/cors/list",
			admin.Token,
			map[string]any{
				"provider_id": brokenTencentProviderID,
			},
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get cors request failed: %v", err)
		}
		defer resp.Body.Close()

		payload := decodeAdminStorageTestCorsGetResponse(t, resp, http.StatusOK)
		if payload.Success {
			t.Fatalf("expected success=false, got true: %+v", payload)
		}
		if len(payload.Rules) != 0 {
			t.Fatalf("expected empty rules, got %+v", payload.Rules)
		}
		if !strings.HasPrefix(payload.Message, "Failed to fetch CORS rules: ") {
			t.Fatalf("unexpected message: %q", payload.Message)
		}
	})
}

func createStorageProviderForMutationFallbackTests(
	t *testing.T,
	c *testutil.Client,
	token string,
	providerType string,
	isActive bool,
	endpoint string,
	bucketName *string,
) string {
	t.Helper()

	payload := map[string]any{
		"provider_type": providerType,
		"name":          fmt.Sprintf("mutation-fallback-%s-%d", providerType, time.Now().UnixNano()),
		"secret_id":     "mock-secret-id",
		"secret_key":    "mock-secret-key",
		"region":        "ap-shanghai",
		"endpoint":      endpoint,
		"is_active":     isActive,
		"is_default":    false,
		"description":   "provider for mutation i18n fallback tests",
	}
	if bucketName != nil {
		payload["bucket_name"] = *bucketName
	}

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers",
		token,
		payload,
	)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create storage provider request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
	}

	var provider struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&provider); err != nil {
		t.Fatalf("decode storage provider response failed: %v", err)
	}
	if provider.ID == "" {
		t.Fatalf("storage provider id is empty")
	}

	return provider.ID
}

func ptrString(value string) *string {
	return &value
}

func decodeAdminStorageTestDeleteResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestDeleteResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestDeleteResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test delete response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestExistsResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestExistsResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestExistsResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test exists response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestCorsSetResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestCorsSetResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestCorsSetResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test cors set response failed: %v", err)
	}

	return payload
}

func decodeAdminStorageTestCorsGetResponse(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
) adminStorageTestCorsGetResponse {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload adminStorageTestCorsGetResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode admin storage test cors get response failed: %v", err)
	}

	return payload
}
