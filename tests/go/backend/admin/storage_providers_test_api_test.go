package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 存储提供商测试接口

func TestStorageProviders_TestBuckets(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/buckets", payload, admin.Token)
	if err != nil {
		t.Fatalf("test buckets http error: %v", err)
	}
	// 可能返回 200（成功）或 400/500（配置无效）
	if resp.StatusCode >= 500 {
		t.Fatalf("test buckets returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestBucketsCreate(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/buckets/create", payload, admin.Token)
	if err != nil {
		t.Fatalf("test buckets create http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test buckets create returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestCors(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/cors", payload, admin.Token)
	if err != nil {
		t.Fatalf("test cors http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test cors returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestCorsList(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/cors/list", payload, admin.Token)
	if err != nil {
		t.Fatalf("test cors list http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test cors list returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestDelete(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/file.txt",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/delete", payload, admin.Token)
	if err != nil {
		t.Fatalf("test delete http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test delete returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestDownloadUrl(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/file.txt",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/download-url", payload, admin.Token)
	if err != nil {
		t.Fatalf("test download url http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test download url returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestExists(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/file.txt",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/exists", payload, admin.Token)
	if err != nil {
		t.Fatalf("test exists http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test exists returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestUpload(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/file.txt",
		"content":       "test content",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/upload", payload, admin.Token)
	if err != nil {
		t.Fatalf("test upload http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test upload returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestMultipartInitiate(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/large-file.bin",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/upload/multipart/initiate", payload, admin.Token)
	if err != nil {
		t.Fatalf("test multipart initiate http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test multipart initiate returned server error: %d", resp.StatusCode)
	}
}

func TestStorageProviders_TestUploadSignature(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"provider_type": "cos",
		"secret_id":     "test-id",
		"secret_key":    "test-key",
		"region":        "ap-shanghai",
		"bucket":        "test-bucket",
		"object_key":    "test/file.txt",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/storage-providers/test/upload/signature", payload, admin.Token)
	if err != nil {
		t.Fatalf("test upload signature http error: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("test upload signature returned server error: %d", resp.StatusCode)
	}
}
