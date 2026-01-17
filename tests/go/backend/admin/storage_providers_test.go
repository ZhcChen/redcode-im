package admin_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type storageProvider struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	IsActive   bool    `json:"is_active"`
	IsDefault  bool    `json:"is_default"`
	Endpoint   string  `json:"endpoint"`
	BucketName *string `json:"bucket_name"`
}

type storageProviderListResponse struct {
	Providers []storageProvider `json:"providers"`
}

func TestAdmin_StorageProviders_CRUD(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin storage providers test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 列表
	respList, bodyList, err := c.DoJSON("GET", "/api/admin/storage-providers", nil, admin.Token)
	if err != nil {
		t.Fatalf("list storage providers http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list storage providers status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list storageProviderListResponse
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode storage providers: %v body=%s", err, string(bodyList))
	}

	// 默认提供商（由 fixture 保证存在）
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)
	respDef, bodyDef, err := c.DoJSON("GET", "/api/admin/storage-providers/default", nil, admin.Token)
	if err != nil {
		t.Fatalf("get default storage provider http error: %v", err)
	}
	if respDef.StatusCode != 200 {
		t.Fatalf("get default storage provider status=%d body=%s", respDef.StatusCode, string(bodyDef))
	}
	var def storageProvider
	if err := testutil.DecodeJSON(bodyDef, &def); err != nil {
		t.Fatalf("decode default storage provider: %v body=%s", err, string(bodyDef))
	}
	if def.ID == "" || def.Name == "" {
		t.Fatalf("expected default provider id/name, body=%s", string(bodyDef))
	}

	// 创建一个非 default 的 provider（避免影响其他并行用例）
	name := "go-test-provider-crud-" + time.Now().Format("150405.000000000")
	createPayload := map[string]any{
		"provider_type": "tencent_cos",
		"name":          name,
		"secret_id":     "AKIDEXAMPLE",
		"secret_key":    "SECRETKEYEXAMPLE",
		"region":        "ap-guangzhou",
		"endpoint":      "localhost",
		"bucket_name":   "redcode-im-test-bucket",
		"is_active":     true,
		"is_default":    false,
		"description":   "go-test-crud",
	}
	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/storage-providers", createPayload, admin.Token)
	if err != nil {
		t.Fatalf("create storage provider http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create storage provider status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created storageProvider
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode created storage provider: %v body=%s", err, string(bodyCreate))
	}
	if created.ID == "" || created.Name != name {
		t.Fatalf("unexpected created provider: id=%q name=%q body=%s", created.ID, created.Name, string(bodyCreate))
	}
	if created.IsDefault {
		t.Fatalf("expected created provider is_default=false, body=%s", string(bodyCreate))
	}

	// 更新（PATCH）
	updatedName := name + "-updated"
	respPatch, bodyPatch, err := c.DoJSON("PATCH", "/api/admin/storage-providers/"+created.ID, map[string]any{
		"name":       updatedName,
		"is_active":  false,
		"is_default": false,
	}, admin.Token)
	if err != nil {
		t.Fatalf("patch storage provider http error: %v", err)
	}
	if respPatch.StatusCode != 200 {
		t.Fatalf("patch storage provider status=%d body=%s", respPatch.StatusCode, string(bodyPatch))
	}
	var patched storageProvider
	if err := testutil.DecodeJSON(bodyPatch, &patched); err != nil {
		t.Fatalf("decode patched provider: %v body=%s", err, string(bodyPatch))
	}
	if patched.Name != updatedName {
		t.Fatalf("expected patched name=%q, got %q body=%s", updatedName, patched.Name, string(bodyPatch))
	}

	// 删除（NO_CONTENT）
	respDel, bodyDel, err := c.DoJSON("DELETE", "/api/admin/storage-providers/"+created.ID, nil, admin.Token)
	if err != nil {
		t.Fatalf("delete storage provider http error: %v", err)
	}
	if respDel.StatusCode != 204 {
		t.Fatalf("expected delete storage provider status=204, got %d body=%s", respDel.StatusCode, string(bodyDel))
	}

	// 非管理员访问必须 403
	pass := "Passw0rd!"
	u := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	usr := testutil.Login(t, c, u.Username, pass)
	respForbidden, bodyForbidden, err := c.DoJSON("GET", "/api/admin/storage-providers", nil, usr.Token)
	if err != nil {
		t.Fatalf("list storage providers (non-admin) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected non-admin status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}
}
