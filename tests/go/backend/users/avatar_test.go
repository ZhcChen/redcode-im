package users_test

import (
	"os"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type avatarDirectUploadResp struct {
	Success   bool   `json:"success"`
	Message   string `json:"message"`
	Key       *string `json:"key"`
	Signature *struct {
		URL    string `json:"url"`
		Method string `json:"method"`
		Key    string `json:"key"`
	} `json:"signature"`
}

type avatarDownloadURLResp struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	DownloadURL *string `json:"download_url"`
}

func TestUsers_Avatar_DirectUploadAndDownloadURL(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip avatar test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	loginA := testutil.Login(t, c, userA.Username, pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	// 直传签名
	resp1, body1, err := c.DoJSON("POST", "/users/me/avatar/direct-upload", map[string]any{
		"content_type": "image/png",
		"file_size":    1024,
	}, loginA.Token)
	if err != nil {
		t.Fatalf("avatar direct-upload http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("avatar direct-upload status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var du avatarDirectUploadResp
	if err := testutil.DecodeJSON(body1, &du); err != nil {
		t.Fatalf("decode avatar direct-upload: %v body=%s", err, string(body1))
	}
	if !du.Success || du.Key == nil || *du.Key == "" || du.Signature == nil || du.Signature.URL == "" {
		t.Fatalf("unexpected avatar direct-upload resp: %+v body=%s", du, string(body1))
	}

	// 未设置 avatar_object_key：返回 success=false（但 200）
	resp2, body2, err := c.DoJSON("GET", "/users/me/avatar/url", nil, loginA.Token)
	if err != nil {
		t.Fatalf("avatar url http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("avatar url status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var noAvatar avatarDownloadURLResp
	if err := testutil.DecodeJSON(body2, &noAvatar); err != nil {
		t.Fatalf("decode avatar url: %v body=%s", err, string(body2))
	}
	if noAvatar.Success {
		t.Fatalf("expected success=false when no avatar set, got %+v", noAvatar)
	}

	// commit（测试栈禁用 COS 网络读写；仅验证 key 校验与状态更新链路）
	resp3, body3, err := c.DoJSON("POST", "/users/me/avatar/commit", map[string]any{
		"key":                *du.Key,
		"expires_in_seconds": 60,
	}, loginA.Token)
	if err != nil {
		t.Fatalf("avatar commit http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("avatar commit status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var commitResp avatarDownloadURLResp
	if err := testutil.DecodeJSON(body3, &commitResp); err != nil {
		t.Fatalf("decode avatar commit: %v body=%s", err, string(body3))
	}
	if !commitResp.Success || commitResp.DownloadURL == nil || !strings.Contains(*commitResp.DownloadURL, "q-sign-algorithm=") {
		t.Fatalf("unexpected avatar commit resp: %+v body=%s", commitResp, string(body3))
	}

	// 自己取头像下载 URL
	resp4, body4, err := c.DoJSON("GET", "/users/me/avatar/url", nil, loginA.Token)
	if err != nil {
		t.Fatalf("avatar url (after set) http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("avatar url (after set) status=%d body=%s", resp4.StatusCode, string(body4))
	}
	var got avatarDownloadURLResp
	if err := testutil.DecodeJSON(body4, &got); err != nil {
		t.Fatalf("decode avatar url (after set): %v body=%s", err, string(body4))
	}
	if !got.Success || got.DownloadURL == nil || !strings.Contains(*got.DownloadURL, "q-sign-algorithm=") {
		t.Fatalf("unexpected avatar url resp: %+v", got)
	}

	// 他人取头像下载 URL（需要 token）
	resp5, body5, err := c.DoJSON("GET", "/users/"+userA.ID+"/avatar/url", nil, loginB.Token)
	if err != nil {
		t.Fatalf("user avatar url http error: %v", err)
	}
	if resp5.StatusCode != 200 {
		t.Fatalf("user avatar url status=%d body=%s", resp5.StatusCode, string(body5))
	}
	var got2 avatarDownloadURLResp
	if err := testutil.DecodeJSON(body5, &got2); err != nil {
		t.Fatalf("decode user avatar url: %v body=%s", err, string(body5))
	}
	if !got2.Success || got2.DownloadURL == nil || !strings.Contains(*got2.DownloadURL, "q-sign-algorithm=") {
		t.Fatalf("unexpected user avatar url resp: %+v", got2)
	}
}
