package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type storageConfigSummary struct {
	Source                   string  `json:"source"`
	Version                  *int    `json:"version"`
	Endpoint                 *string `json:"endpoint"`
	Region                   string  `json:"region"`
	PrivateBucket            string  `json:"private_bucket"`
	PublicBucket             *string `json:"public_bucket"`
	PublicBaseURL            *string `json:"public_base_url"`
	KeyIDConfigured          bool    `json:"key_id_configured"`
	ApplicationKeyConfigured bool    `json:"application_key_configured"`
}

type storageConfigProbeResponse struct {
	Normalized storageConfigSummary `json:"normalized"`
	Probe      struct {
		Status              string   `json:"status"`
		AllowedCapabilities []string `json:"allowed_capabilities"`
		S3APIURL            *string  `json:"s3_api_url"`
	} `json:"probe"`
}

func TestStorageConfigB2UsesExternalMock(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	mockEndpoint := testutil.ExternalMockBaseURL()
	config := map[string]any{
		"endpoint":        mockEndpoint,
		"region":          "us-east-005",
		"key_id":          "mock-key-id",
		"application_key": "mock-application-key",
		"private_bucket":  "mock-bucket",
		"public_bucket":   "mock-bucket",
		"public_base_url": mockEndpoint + "/mock-bucket",
	}

	probeReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/system/storage-config/probe",
		admin.Token,
		map[string]any{"config": config},
	)
	probeResp, err := c.HTTP.Do(probeReq)
	if err != nil {
		t.Fatalf("probe storage config failed: %v", err)
	}
	defer probeResp.Body.Close()
	if probeResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(probeResp.Body)
		t.Fatalf("probe storage config expect 200, got %d: %s", probeResp.StatusCode, string(body))
	}

	var probePayload storageConfigProbeResponse
	if err := json.NewDecoder(probeResp.Body).Decode(&probePayload); err != nil {
		t.Fatalf("decode probe response failed: %v", err)
	}
	if probePayload.Probe.Status != "pass" {
		t.Fatalf("probe should pass against external mock: %+v", probePayload.Probe)
	}
	if probePayload.Probe.S3APIURL == nil || *probePayload.Probe.S3APIURL != mockEndpoint {
		t.Fatalf("probe should report external mock endpoint, got %+v", probePayload.Probe.S3APIURL)
	}
	if endpointValue(probePayload.Normalized.Endpoint) != mockEndpoint {
		t.Fatalf("normalized endpoint should be external mock, got %+v", probePayload.Normalized.Endpoint)
	}

	applyReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/system/storage-config/apply",
		admin.Token,
		map[string]any{
			"config":      config,
			"change_note": "contract test mock b2 config",
		},
	)
	applyResp, err := c.HTTP.Do(applyReq)
	if err != nil {
		t.Fatalf("apply storage config failed: %v", err)
	}
	defer applyResp.Body.Close()
	if applyResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(applyResp.Body)
		t.Fatalf("apply storage config expect 200, got %d: %s", applyResp.StatusCode, string(body))
	}
	var applyPayload struct {
		Current storageConfigSummary `json:"current"`
	}
	if err := json.NewDecoder(applyResp.Body).Decode(&applyPayload); err != nil {
		t.Fatalf("decode apply response failed: %v", err)
	}
	if endpointValue(applyPayload.Current.Endpoint) != mockEndpoint {
		t.Fatalf("applied endpoint should be external mock, got %+v", applyPayload.Current.Endpoint)
	}
	if !applyPayload.Current.KeyIDConfigured || !applyPayload.Current.ApplicationKeyConfigured {
		t.Fatalf("applied config should report credentials configured: %+v", applyPayload.Current)
	}

	initReq := testutil.NewAuthedJSONRequestWithToken(
		http.MethodPost,
		c.BaseURL+"/api/admin/system/storage-config/init-bucket",
		admin.Token,
		nil,
	)
	initResp, err := c.HTTP.Do(initReq)
	if err != nil {
		t.Fatalf("init storage buckets failed: %v", err)
	}
	defer initResp.Body.Close()
	if initResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(initResp.Body)
		t.Fatalf("init storage buckets expect 200, got %d: %s", initResp.StatusCode, string(body))
	}
	var initPayload struct {
		Result struct {
			Status string `json:"status"`
			Items  []struct {
				BucketName string `json:"bucket_name"`
				Status     string `json:"status"`
			} `json:"items"`
		} `json:"result"`
	}
	if err := json.NewDecoder(initResp.Body).Decode(&initPayload); err != nil {
		t.Fatalf("decode init bucket response failed: %v", err)
	}
	if initPayload.Result.Status != "success" {
		t.Fatalf("init bucket should succeed against external mock: %+v", initPayload.Result)
	}
	if len(initPayload.Result.Items) == 0 || initPayload.Result.Items[0].BucketName != "mock-bucket" {
		t.Fatalf("init bucket should target mock-bucket: %+v", initPayload.Result.Items)
	}
}

func endpointValue(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimRight(*value, "/")
}
