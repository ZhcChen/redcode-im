package messages_test

import (
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type messageAttachmentSignatureResp struct {
	Success   bool   `json:"success"`
	Message   string `json:"message"`
	Key       *string `json:"key"`
	Signature *struct {
		URL    string `json:"url"`
		Method string `json:"method"`
		Key    string `json:"key"`
	} `json:"signature"`
}

type messageAttachmentDownloadResp struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	DownloadURL *string `json:"download_url"`
}

func TestMessages_Attachments_SignatureAndDownloadURL(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip attachment test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-attach-"+time.Now().Format("150405"), []string{user2.ID})

	// 生成附件直传签名（不提供 hash，避免走 file_exists）
	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/signature", map[string]any{
		"part_type":    "image",
		"filename":     "a.png",
		"content_type": "image/png",
		"file_size":    123,
	}, login1.Token)
	if err != nil {
		t.Fatalf("attachment signature http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("attachment signature status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var sig messageAttachmentSignatureResp
	if err := testutil.DecodeJSON(body1, &sig); err != nil {
		t.Fatalf("decode attachment signature: %v body=%s", err, string(body1))
	}
	if !sig.Success || sig.Key == nil || *sig.Key == "" || sig.Signature == nil || sig.Signature.URL == "" {
		t.Fatalf("unexpected attachment signature resp: %+v body=%s", sig, string(body1))
	}

	// 发送一条引用附件 key 的消息（允许“仅引用 key，未走 commit”）
	resp2, body2, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages", map[string]any{
		"parts": []map[string]any{
			{
				"type": "image",
				"key":  *sig.Key,
				"name": "a.png",
				"mime": "image/png",
				"size": 123,
			},
		},
	}, login1.Token)
	if err != nil {
		t.Fatalf("send message (with attachment) http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("send message (with attachment) status=%d body=%s", resp2.StatusCode, string(body2))
	}

	// 取附件下载 URL：必须校验该 key 在房间内已被引用过
	dlPath := "/rooms/" + roomID + "/messages/attachments/download?key=" + url.QueryEscape(*sig.Key) + "&expires_in_seconds=600"
	resp3, body3, err := c.DoJSON("GET", dlPath, nil, login2.Token)
	if err != nil {
		t.Fatalf("attachment download-url http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("attachment download-url status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var dl messageAttachmentDownloadResp
	if err := testutil.DecodeJSON(body3, &dl); err != nil {
		t.Fatalf("decode attachment download-url: %v body=%s", err, string(body3))
	}
	if !dl.Success || dl.DownloadURL == nil || !strings.Contains(*dl.DownloadURL, "q-sign-algorithm=") {
		t.Fatalf("unexpected attachment download-url resp: %+v", dl)
	}
}

