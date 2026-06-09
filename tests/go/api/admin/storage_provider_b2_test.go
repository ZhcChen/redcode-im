package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type storageProviderResponse struct {
	ID                  string `json:"id"`
	Name                string `json:"name"`
	ProviderType        string `json:"provider_type"`
	SecretID            string `json:"secret_id"`
	SecretKey           string `json:"secret_key"`
	SecretIDConfigured  bool   `json:"secret_id_configured"`
	SecretKeyConfigured bool   `json:"secret_key_configured"`
	Region              string `json:"region"`
	Endpoint            string `json:"endpoint"`
	BucketName          string `json:"bucket_name"`
	IsActive            bool   `json:"is_active"`
	IsDefault           bool   `json:"is_default"`
}

type storageProviderListResponse struct {
	Providers []storageProviderResponse `json:"providers"`
}

func TestStorageProviderB2ResponseRedactsSecretsAndPreservesExistingCredentials(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	createPayload := map[string]any{
		"provider_type": "backblaze_b2",
		"name":          fmt.Sprintf("b2_%s", testutil.UniqueUsername("storage")),
		"secret_id":     "b2-key-id",
		"secret_key":    "b2-application-key",
		"region":        "us-east-005",
		"endpoint":      "https://s3.us-east-005.backblazeb2.com",
		"bucket_name":   "redcode-im-private-test",
		"is_active":     true,
		"is_default":    false,
		"description":   "b2 response contract test",
	}

	createReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers",
		admin.Token,
		createPayload,
	)
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		t.Fatalf("create b2 storage provider failed: %v", err)
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		t.Fatalf("create b2 storage provider expect 200, got %d: %s", createResp.StatusCode, string(body))
	}

	var created storageProviderResponse
	if err := json.NewDecoder(createResp.Body).Decode(&created); err != nil {
		t.Fatalf("decode created storage provider failed: %v", err)
	}
	if created.ID == "" || created.ProviderType != "backblaze_b2" {
		t.Fatalf("unexpected created provider: %+v", created)
	}
	if created.SecretID != "" || created.SecretKey != "" {
		t.Fatalf("storage provider response should redact secrets: %+v", created)
	}
	if !created.SecretIDConfigured || !created.SecretKeyConfigured {
		t.Fatalf("storage provider response should expose configured flags: %+v", created)
	}

	updatePayload := map[string]any{
		"name":       created.Name + "_updated",
		"secret_id":  "",
		"secret_key": "",
	}
	updateReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPatch,
		c.BaseURL+"/api/admin/storage-providers/"+created.ID,
		admin.Token,
		updatePayload,
	)
	updateResp, err := c.HTTP.Do(updateReq)
	if err != nil {
		t.Fatalf("update b2 storage provider failed: %v", err)
	}
	defer updateResp.Body.Close()
	if updateResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(updateResp.Body)
		t.Fatalf("update b2 storage provider expect 200, got %d: %s", updateResp.StatusCode, string(body))
	}

	var updated storageProviderResponse
	if err := json.NewDecoder(updateResp.Body).Decode(&updated); err != nil {
		t.Fatalf("decode updated storage provider failed: %v", err)
	}
	if updated.Name != updatePayload["name"] {
		t.Fatalf("storage provider name not updated: %+v", updated)
	}
	if updated.SecretID != "" || updated.SecretKey != "" {
		t.Fatalf("updated storage provider response should redact secrets: %+v", updated)
	}
	if !updated.SecretIDConfigured || !updated.SecretKeyConfigured {
		t.Fatalf("updated storage provider should still report configured secrets: %+v", updated)
	}

	listReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodGet,
		c.BaseURL+"/api/admin/storage-providers",
		admin.Token,
		nil,
	)
	listResp, err := c.HTTP.Do(listReq)
	if err != nil {
		t.Fatalf("list storage providers failed: %v", err)
	}
	defer listResp.Body.Close()
	if listResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(listResp.Body)
		t.Fatalf("list storage providers expect 200, got %d: %s", listResp.StatusCode, string(body))
	}

	var listed storageProviderListResponse
	if err := json.NewDecoder(listResp.Body).Decode(&listed); err != nil {
		t.Fatalf("decode storage providers failed: %v", err)
	}

	var found *storageProviderResponse
	for i := range listed.Providers {
		if listed.Providers[i].ID == created.ID {
			found = &listed.Providers[i]
			break
		}
	}
	if found == nil {
		t.Fatalf("created provider not found in list: %+v", listed)
	}
	if found.SecretID != "" || found.SecretKey != "" {
		t.Fatalf("listed storage provider should redact secrets: %+v", found)
	}
	if !found.SecretIDConfigured || !found.SecretKeyConfigured {
		t.Fatalf("listed storage provider should expose configured flags: %+v", found)
	}
}

func TestStorageProviderB2RequiresBucketName(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	createPayload := map[string]any{
		"provider_type": "backblaze_b2",
		"name":          fmt.Sprintf("b2_%s", testutil.UniqueUsername("bucket")),
		"secret_id":     "b2-key-id",
		"secret_key":    "b2-application-key",
		"region":        "us-east-005",
		"endpoint":      "https://s3.us-east-005.backblazeb2.com",
		"bucket_name":   "",
		"is_active":     true,
	}

	req := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers",
		admin.Token,
		createPayload,
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create b2 storage provider without bucket failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		t.Fatalf("create b2 storage provider without bucket should fail")
	}

	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "bucket_name") {
		t.Fatalf("expected bucket_name validation message, got: %s", string(body))
	}
}

func TestStorageProviderB2UpdateRejectsClearingBucketName(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	createPayload := map[string]any{
		"provider_type": "backblaze_b2",
		"name":          fmt.Sprintf("b2_%s", testutil.UniqueUsername("patch")),
		"secret_id":     "b2-key-id",
		"secret_key":    "b2-application-key",
		"region":        "us-east-005",
		"endpoint":      "https://s3.us-east-005.backblazeb2.com",
		"bucket_name":   "redcode-im-private-test",
		"is_active":     true,
		"is_default":    false,
		"description":   "b2 update validation contract test",
	}

	createReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/storage-providers",
		admin.Token,
		createPayload,
	)
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		t.Fatalf("create b2 storage provider failed: %v", err)
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		t.Fatalf("create b2 storage provider expect 200, got %d: %s", createResp.StatusCode, string(body))
	}

	var created storageProviderResponse
	if err := json.NewDecoder(createResp.Body).Decode(&created); err != nil {
		t.Fatalf("decode created storage provider failed: %v", err)
	}
	if created.ID == "" {
		t.Fatalf("created provider id is empty: %+v", created)
	}

	updatePayload := map[string]any{
		"bucket_name": "",
	}
	updateReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPatch,
		c.BaseURL+"/api/admin/storage-providers/"+created.ID,
		admin.Token,
		updatePayload,
	)
	updateResp, err := c.HTTP.Do(updateReq)
	if err != nil {
		t.Fatalf("update b2 storage provider failed: %v", err)
	}
	defer updateResp.Body.Close()
	if updateResp.StatusCode == http.StatusOK {
		t.Fatalf("update b2 storage provider clearing bucket_name should fail")
	}

	body, _ := io.ReadAll(updateResp.Body)
	if !strings.Contains(string(body), "bucket_name") {
		t.Fatalf("expected bucket_name validation message, got: %s", string(body))
	}
}
