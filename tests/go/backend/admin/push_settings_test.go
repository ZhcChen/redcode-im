package admin_test

import (
	"os"
	"slices"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type pushProviderConfigView struct {
	ID               string `json:"id"`
	Provider         string `json:"provider"`
	Platform         string `json:"platform"`
	Enabled          bool   `json:"enabled"`
	HasSecret        bool   `json:"has_secret"`
	SecretFingerprint *string `json:"secret_fingerprint"`
	UpdatedAt        string `json:"updated_at"`
	UpdatedBy        *string `json:"updated_by"`
}

type pushSettingsResponse struct {
	Enabled      bool                   `json:"enabled"`
	SkipIfOnline bool                   `json:"skip_if_online"`
	Providers    []pushProviderConfigView `json:"providers"`
}

func TestAdmin_PushSettings_GetAndUpdate(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push settings test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp0, body0, err := c.DoJSON("GET", "/api/admin/settings/push", nil, admin.Token)
	if err != nil {
		t.Fatalf("get push settings http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("get push settings status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var original pushSettingsResponse
	if err := testutil.DecodeJSON(body0, &original); err != nil {
		t.Fatalf("decode push settings: %v body=%s", err, string(body0))
	}

	t.Cleanup(func() {
		_, _, _ = c.DoJSON("PUT", "/api/admin/settings/push", map[string]any{
			"enabled":        original.Enabled,
			"skip_if_online": original.SkipIfOnline,
		}, admin.Token)
	})

	resp1, body1, err := c.DoJSON("PUT", "/api/admin/settings/push", map[string]any{
		"enabled":        !original.Enabled,
		"skip_if_online": original.SkipIfOnline,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update push settings http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("update push settings status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var updated pushSettingsResponse
	if err := testutil.DecodeJSON(body1, &updated); err != nil {
		t.Fatalf("decode update push settings: %v body=%s", err, string(body1))
	}
	if updated.Enabled == original.Enabled {
		t.Fatalf("expected enabled toggled, original=%v updated=%v body=%s", original.Enabled, updated.Enabled, string(body1))
	}
	if updated.SkipIfOnline != original.SkipIfOnline {
		t.Fatalf("expected skip_if_online unchanged, original=%v updated=%v body=%s", original.SkipIfOnline, updated.SkipIfOnline, string(body1))
	}
}

func TestAdmin_PushSettings_UpsertProvider_UnsupportedRejected(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push provider test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("PUT", "/api/admin/settings/push/providers/apns", map[string]any{
		"enabled": true,
	}, admin.Token)
	if err != nil {
		t.Fatalf("upsert push provider (unsupported) http error: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("expected upsert push provider (unsupported)=400, got %d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_PushSettings_UpsertProvider_UUIDPath_Unsupported(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push provider test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("PUT", "/api/admin/settings/push/providers/00000000-0000-0000-0000-000000000000", map[string]any{
		"enabled": true,
	}, admin.Token)
	if err != nil {
		t.Fatalf("upsert push provider (uuid) http error: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("expected upsert push provider (uuid)=400, got %d body=%s", resp.StatusCode, string(body))
	}
}

func TestAdmin_PushSettings_UpsertProvider_FCM_Minimal(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push provider test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 先读取现有 providers，方便回滚 enabled 状态
	_, body0, err := c.DoJSON("GET", "/api/admin/settings/push", nil, admin.Token)
	if err != nil {
		t.Fatalf("get push settings http error: %v", err)
	}
	var original pushSettingsResponse
	if err := testutil.DecodeJSON(body0, &original); err != nil {
		t.Fatalf("decode push settings: %v body=%s", err, string(body0))
	}

	var originalFCM *pushProviderConfigView
	for i := range original.Providers {
		p := &original.Providers[i]
		if p.Provider == "fcm" && p.Platform == "all" {
			originalFCM = p
			break
		}
	}

	t.Cleanup(func() {
		if originalFCM == nil {
			return
		}
		_, _, _ = c.DoJSON("PUT", "/api/admin/settings/push/providers/fcm", map[string]any{
			"enabled": originalFCM.Enabled,
		}, admin.Token)
	})

	resp, body, err := c.DoJSON("PUT", "/api/admin/settings/push/providers/fcm", map[string]any{
		"enabled": false,
	}, admin.Token)
	if err != nil {
		t.Fatalf("upsert push provider (fcm) http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("upsert push provider (fcm) status=%d body=%s", resp.StatusCode, string(body))
	}
	var out pushProviderConfigView
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode upsert push provider (fcm): %v body=%s", err, string(body))
	}
	if out.Provider != "fcm" || out.Platform != "all" {
		t.Fatalf("unexpected provider view: %+v body=%s", out, string(body))
	}
	if out.Enabled != false {
		t.Fatalf("expected enabled=false, got %v body=%s", out.Enabled, string(body))
	}

	// 再次拉取 settings，确保 providers 中存在 fcm/all
	resp2, body2, err := c.DoJSON("GET", "/api/admin/settings/push", nil, admin.Token)
	if err != nil {
		t.Fatalf("get push settings (after) http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("get push settings (after) status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var after pushSettingsResponse
	if err := testutil.DecodeJSON(body2, &after); err != nil {
		t.Fatalf("decode push settings (after): %v body=%s", err, string(body2))
	}
	if !slices.ContainsFunc(after.Providers, func(p pushProviderConfigView) bool { return p.Provider == "fcm" && p.Platform == "all" }) {
		t.Fatalf("expected fcm provider present, got %+v", after.Providers)
	}
}

func TestAdmin_PushSettings_TestPush_Validations(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin push test validation")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// unsupported provider
	resp0, body0, err := c.DoJSON("POST", "/api/admin/settings/push/test", map[string]any{
		"provider": "apns",
		"title":    "t",
		"body":     "b",
	}, admin.Token)
	if err != nil {
		t.Fatalf("test push (unsupported) http error: %v", err)
	}
	if resp0.StatusCode != 400 {
		t.Fatalf("expected test push (unsupported)=400, got %d body=%s", resp0.StatusCode, string(body0))
	}

	// missing device_token/user_id should be 400 (不会触发真实网络请求)
	resp1, body1, err := c.DoJSON("POST", "/api/admin/settings/push/test", map[string]any{
		"provider": "fcm",
		"title":    "t",
		"body":     "b",
	}, admin.Token)
	if err != nil {
		t.Fatalf("test push (missing token) http error: %v", err)
	}
	if resp1.StatusCode != 400 {
		t.Fatalf("expected test push (missing token)=400, got %d body=%s", resp1.StatusCode, string(body1))
	}
}
