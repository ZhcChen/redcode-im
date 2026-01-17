package rooms_test

import (
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type roomAvatarDirectUploadResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Key     *string `json:"key"`
	Signature *struct {
		URL    string `json:"url"`
		Method string `json:"method"`
		Key    string `json:"key"`
	} `json:"signature"`
}

type roomAvatarCommitResp struct {
	Success   bool    `json:"success"`
	Message   string  `json:"message"`
	AvatarURL *string `json:"avatar_url"`
}

type roomAvatarDownloadURLResp struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	DownloadURL *string `json:"download_url"`
}

func TestRooms_Avatar_DirectUploadCommitAndDownloadURL(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip room avatar test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-room-avatar-"+time.Now().Format("150405"), []string{member.ID})

	// 非 owner/admin 不能生成直传签名
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/avatar/direct-upload", map[string]any{
		"filename":     "x.png",
		"content_type": "image/png",
		"file_size":    1024,
	}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member room avatar direct-upload http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected member room avatar direct-upload=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/avatar/direct-upload", map[string]any{
		"filename":     "avatar.png",
		"content_type": "image/png",
		"file_size":    1024,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("room avatar direct-upload http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("room avatar direct-upload status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var du roomAvatarDirectUploadResp
	if err := testutil.DecodeJSON(body1, &du); err != nil {
		t.Fatalf("decode room avatar direct-upload: %v body=%s", err, string(body1))
	}
	if !du.Success || du.Key == nil || *du.Key == "" || du.Signature == nil || du.Signature.URL == "" {
		t.Fatalf("unexpected room avatar direct-upload resp: %+v body=%s", du, string(body1))
	}

	// commit（测试栈禁用 COS 网络读写；仅验证 key 校验与状态更新链路）
	resp2, body2, err := c.DoJSON("POST", "/rooms/"+roomID+"/avatar/commit", map[string]any{
		"key": *du.Key,
	}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("room avatar commit http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("room avatar commit status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var cr roomAvatarCommitResp
	if err := testutil.DecodeJSON(body2, &cr); err != nil {
		t.Fatalf("decode room avatar commit: %v body=%s", err, string(body2))
	}
	if !cr.Success || cr.AvatarURL == nil || *cr.AvatarURL == "" {
		t.Fatalf("unexpected room avatar commit resp: %+v body=%s", cr, string(body2))
	}

	// download url
	resp3, body3, err := c.DoJSON("GET", "/rooms/"+roomID+"/avatar/url?expires_in_seconds=60", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("room avatar url http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("room avatar url status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var dl roomAvatarDownloadURLResp
	if err := testutil.DecodeJSON(body3, &dl); err != nil {
		t.Fatalf("decode room avatar url: %v body=%s", err, string(body3))
	}
	if !dl.Success || dl.DownloadURL == nil || !strings.Contains(*dl.DownloadURL, "q-sign-algorithm=") {
		t.Fatalf("unexpected room avatar url resp: %+v body=%s", dl, string(body3))
	}
}

