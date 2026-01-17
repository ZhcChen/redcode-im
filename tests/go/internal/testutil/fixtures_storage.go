package testutil

import (
	"fmt"
	"testing"
)

type storageProviderResponse struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	IsDefault bool   `json:"is_default"`
}

type storageProviderListResponse struct {
	Providers []storageProviderResponse `json:"providers"`
}

// EnsureDefaultStorageProvider 创建/复用一个可用于“生成签名/下载 URL”的默认存储提供商（测试用）。
//
// 注意：
// - 不会校验 endpoint 可连通性；仅用于本地签名生成与 URL 拼装（避免依赖外网/真实 COS）。
// - go test 会并行跑 package，这里尽量做到幂等复用，减少数据膨胀与并发抖动。
func EnsureDefaultStorageProvider(t *testing.T, c *Client, adminToken string) string {
	t.Helper()

	const providerName = "go-test-provider"

	if id := tryGetStorageProviderByName(t, c, adminToken, providerName); id != "" {
		return id
	}

	payload := map[string]any{
		"provider_type": "tencent_cos",
		"name":          providerName,
		"secret_id":     "AKIDEXAMPLE",
		"secret_key":    "SECRETKEYEXAMPLE",
		"region":        "ap-guangzhou",
		"endpoint":      "localhost",
		"bucket_name":   "redcode-im-test-bucket",
		"is_active":     true,
		"is_default":    true,
		"description":   "go-test",
	}

	resp, body, err := c.DoJSON("POST", "/api/admin/storage-providers", payload, adminToken)
	if err != nil {
		t.Fatalf("create storage provider http error: %v", err)
	}
	if resp.StatusCode != 200 {
		if id := tryGetStorageProviderByName(t, c, adminToken, providerName); id != "" {
			return id
		}
		t.Fatalf("create storage provider status=%d body=%s", resp.StatusCode, string(body))
	}
	var out storageProviderResponse
	if err := DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode storage provider: %v body=%s", err, string(body))
	}
	if out.ID == "" {
		t.Fatalf("expected storage provider id, got empty: body=%s", string(body))
	}
	return out.ID
}

func tryGetStorageProviderByName(t *testing.T, c *Client, adminToken, name string) string {
	t.Helper()

	resp, body, err := c.DoJSON("GET", "/api/admin/storage-providers", nil, adminToken)
	if err != nil {
		return ""
	}
	if resp.StatusCode != 200 {
		return ""
	}

	var out storageProviderListResponse
	if err := DecodeJSON(body, &out); err != nil {
		return ""
	}

	for _, p := range out.Providers {
		if p.Name != name || p.ID == "" {
			continue
		}

		if p.IsDefault {
			return p.ID
		}

		update := map[string]any{
			"is_active":  true,
			"is_default": true,
		}
		resp2, body2, err := c.DoJSON("PATCH", fmt.Sprintf("/api/admin/storage-providers/%s", p.ID), update, adminToken)
		if err != nil {
			t.Fatalf("update storage provider http error: %v", err)
		}
		if resp2.StatusCode != 200 {
			t.Fatalf("update storage provider status=%d body=%s", resp2.StatusCode, string(body2))
		}
		return p.ID
	}
	return ""
}
