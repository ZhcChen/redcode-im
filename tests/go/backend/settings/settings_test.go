package settings_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type documentContent struct {
	Key       string  `json:"key"`
	Title     string  `json:"title"`
	Content   string  `json:"content"`
	UpdatedAt string  `json:"updated_at"`
	UpdatedBy *string `json:"updated_by"`
}

type generalSettings struct {
	AppName string `json:"app_name"`
}

type captchaSetting struct {
	RequireCaptchaForLogin bool `json:"require_captcha_for_login"`
}

func TestSettings_PublicEndpoints(t *testing.T) {
	c := testutil.NewClient()

	resp, body, err := c.DoJSON("GET", "/settings/general", nil, "")
	if err != nil {
		t.Fatalf("get settings general http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get settings general status=%d body=%s", resp.StatusCode, string(body))
	}
	var gs generalSettings
	if err := testutil.DecodeJSON(body, &gs); err != nil {
		t.Fatalf("decode settings general: %v body=%s", err, string(body))
	}
	if gs.AppName == "" {
		t.Fatalf("expected app_name non-empty, body=%s", string(body))
	}

	resp2, body2, err := c.DoJSON("GET", "/settings/app-name", nil, "")
	if err != nil {
		t.Fatalf("get app-name http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("get app-name status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var an generalSettings
	if err := testutil.DecodeJSON(body2, &an); err != nil {
		t.Fatalf("decode app-name: %v body=%s", err, string(body2))
	}
	if an.AppName == "" {
		t.Fatalf("expected app_name non-empty, body=%s", string(body2))
	}

	resp3, body3, err := c.DoJSON("GET", "/settings/captcha", nil, "")
	if err != nil {
		t.Fatalf("get captcha setting http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("get captcha setting status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var cs captchaSetting
	if err := testutil.DecodeJSON(body3, &cs); err != nil {
		t.Fatalf("decode captcha setting: %v body=%s", err, string(body3))
	}

	_ = cs.RequireCaptchaForLogin // 只要能解析即满足契约

	resp4, body4, err := c.DoJSON("GET", "/settings/privacy-policy", nil, "")
	if err != nil {
		t.Fatalf("get privacy-policy http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("get privacy-policy status=%d body=%s", resp4.StatusCode, string(body4))
	}
	var pp documentContent
	if err := testutil.DecodeJSON(body4, &pp); err != nil {
		t.Fatalf("decode privacy-policy: %v body=%s", err, string(body4))
	}
	if pp.Key != "privacy_policy" || pp.Title == "" || pp.Content == "" || pp.UpdatedAt == "" {
		t.Fatalf("unexpected privacy-policy: %+v", pp)
	}

	resp5, body5, err := c.DoJSON("GET", "/settings/user-agreement", nil, "")
	if err != nil {
		t.Fatalf("get user-agreement http error: %v", err)
	}
	if resp5.StatusCode != 200 {
		t.Fatalf("get user-agreement status=%d body=%s", resp5.StatusCode, string(body5))
	}
	var ua documentContent
	if err := testutil.DecodeJSON(body5, &ua); err != nil {
		t.Fatalf("decode user-agreement: %v body=%s", err, string(body5))
	}
	if ua.Key != "user_agreement" || ua.Title == "" || ua.Content == "" || ua.UpdatedAt == "" {
		t.Fatalf("unexpected user-agreement: %+v", ua)
	}
}

func TestSettings_AdminUpdate_AppNameAndDocuments(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin settings test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 读取原 app_name
	_, body0, err := c.DoJSON("GET", "/settings/app-name", nil, "")
	if err != nil {
		t.Fatalf("get app-name http error: %v", err)
	}
	var originalApp generalSettings
	if err := testutil.DecodeJSON(body0, &originalApp); err != nil {
		t.Fatalf("decode app-name: %v body=%s", err, string(body0))
	}

	newAppName := "go-app-" + time.Now().Format("150405.000000000")
	t.Cleanup(func() {
		_, _, _ = c.DoJSON("PUT", "/api/admin/settings/app-name", map[string]any{"app_name": originalApp.AppName}, admin.Token)
	})

	resp1, body1, err := c.DoJSON("PUT", "/api/admin/settings/app-name", map[string]any{"app_name": newAppName}, admin.Token)
	if err != nil {
		t.Fatalf("update app-name http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("update app-name status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var updatedApp generalSettings
	if err := testutil.DecodeJSON(body1, &updatedApp); err != nil {
		t.Fatalf("decode update app-name: %v body=%s", err, string(body1))
	}
	if updatedApp.AppName != newAppName {
		t.Fatalf("expected app_name=%q, got %q", newAppName, updatedApp.AppName)
	}

	// 读取原隐私协议并更新，最后回滚
	_, bodyPP0, err := c.DoJSON("GET", "/settings/privacy-policy", nil, "")
	if err != nil {
		t.Fatalf("get privacy-policy http error: %v", err)
	}
	var originalPP documentContent
	if err := testutil.DecodeJSON(bodyPP0, &originalPP); err != nil {
		t.Fatalf("decode privacy-policy: %v body=%s", err, string(bodyPP0))
	}
	t.Cleanup(func() {
		_, _, _ = c.DoJSON("POST", "/api/admin/settings/privacy-policy", map[string]any{
			"title":   originalPP.Title,
			"content": originalPP.Content,
		}, admin.Token)
	})

	newPPTitle := "go-pp-" + time.Now().Format("150405.000000000")
	newPPContent := "<p>pp-" + time.Now().Format("150405.000000000") + "</p>"
	respPP, bodyPP, err := c.DoJSON("POST", "/api/admin/settings/privacy-policy", map[string]any{
		"title":   newPPTitle,
		"content": newPPContent,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update privacy-policy http error: %v", err)
	}
	if respPP.StatusCode != 200 {
		t.Fatalf("update privacy-policy status=%d body=%s", respPP.StatusCode, string(bodyPP))
	}

	_, bodyPPGet, err := c.DoJSON("GET", "/settings/privacy-policy", nil, "")
	if err != nil {
		t.Fatalf("get privacy-policy (after) http error: %v", err)
	}
	var gotPP documentContent
	if err := testutil.DecodeJSON(bodyPPGet, &gotPP); err != nil {
		t.Fatalf("decode privacy-policy (after): %v body=%s", err, string(bodyPPGet))
	}
	if gotPP.Title != newPPTitle || gotPP.Content != newPPContent {
		t.Fatalf("expected privacy-policy updated, got %+v", gotPP)
	}

	// 读取原用户协议并更新，最后回滚
	_, bodyUA0, err := c.DoJSON("GET", "/settings/user-agreement", nil, "")
	if err != nil {
		t.Fatalf("get user-agreement http error: %v", err)
	}
	var originalUA documentContent
	if err := testutil.DecodeJSON(bodyUA0, &originalUA); err != nil {
		t.Fatalf("decode user-agreement: %v body=%s", err, string(bodyUA0))
	}
	t.Cleanup(func() {
		_, _, _ = c.DoJSON("POST", "/api/admin/settings/user-agreement", map[string]any{
			"title":   originalUA.Title,
			"content": originalUA.Content,
		}, admin.Token)
	})

	newUATitle := "go-ua-" + time.Now().Format("150405.000000000")
	newUAContent := "<p>ua-" + time.Now().Format("150405.000000000") + "</p>"
	respUA, bodyUA, err := c.DoJSON("POST", "/api/admin/settings/user-agreement", map[string]any{
		"title":   newUATitle,
		"content": newUAContent,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user-agreement http error: %v", err)
	}
	if respUA.StatusCode != 200 {
		t.Fatalf("update user-agreement status=%d body=%s", respUA.StatusCode, string(bodyUA))
	}

	_, bodyUAGet, err := c.DoJSON("GET", "/settings/user-agreement", nil, "")
	if err != nil {
		t.Fatalf("get user-agreement (after) http error: %v", err)
	}
	var gotUA documentContent
	if err := testutil.DecodeJSON(bodyUAGet, &gotUA); err != nil {
		t.Fatalf("decode user-agreement (after): %v body=%s", err, string(bodyUAGet))
	}
	if gotUA.Title != newUATitle || gotUA.Content != newUAContent {
		t.Fatalf("expected user-agreement updated, got %+v", gotUA)
	}
}

