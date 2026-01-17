package messages_test

import (
	"net/url"
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type messageAttachmentCommitResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestMessages_Attachments_CommitFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip attachment commit test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user3 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass) // 非群成员

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)
	login3 := testutil.Login(t, c, user3.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-attach-commit-"+time.Now().Format("150405"), []string{user2.ID})

	// 生成附件直传签名
	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/signature", map[string]any{
		"part_type":    "image",
		"filename":     "a.png",
		"content_type": "image/png",
		"file_size":    123,
		"hash_value":   "d41d8cd98f00b204e9800998ecf8427e",
		"hash_alg":     1,
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
	if !sig.Success || sig.Key == nil || *sig.Key == "" {
		t.Fatalf("unexpected attachment signature resp: %+v body=%s", sig, string(body1))
	}

	// 非成员提交应 403
	respForbidden, bodyForbidden, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/commit", map[string]any{
		"key":       *sig.Key,
		"file_size": 123,
	}, login3.Token)
	if err != nil {
		t.Fatalf("attachment commit (non-member) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected attachment commit (non-member) status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}

	// 提交上传完成（测试栈会跳过真实 COS 校验；这里仍走完整 API 链路）
	respCommit, bodyCommit, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/commit", map[string]any{
		"key":        *sig.Key,
		"file_size":  123,
		"hash_value": "d41d8cd98f00b204e9800998ecf8427e",
		"hash_alg":   1,
	}, login1.Token)
	if err != nil {
		t.Fatalf("attachment commit http error: %v", err)
	}
	if respCommit.StatusCode != 200 {
		t.Fatalf("attachment commit status=%d body=%s", respCommit.StatusCode, string(bodyCommit))
	}
	var commit messageAttachmentCommitResp
	if err := testutil.DecodeJSON(bodyCommit, &commit); err != nil {
		t.Fatalf("decode attachment commit: %v body=%s", err, string(bodyCommit))
	}
	if !commit.Success {
		t.Fatalf("expected attachment commit success=true, body=%s", string(bodyCommit))
	}

	// 发送引用该 key 的消息
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

	// 下载 URL：必须校验该 key 在房间内已被引用过
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
	if !dl.Success || dl.DownloadURL == nil || *dl.DownloadURL == "" {
		t.Fatalf("unexpected attachment download-url resp: %+v", dl)
	}
}

