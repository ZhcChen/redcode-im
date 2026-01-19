package messages_test

import (
	"encoding/base64"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

func TestSendEncryptedMessage_Success(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	// 创建两个用户和房间
	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "e2ee-test-"+time.Now().Format("150405"), []string{member.ID})

	// 发送加密消息
	encryptedContent := base64.StdEncoding.EncodeToString([]byte("encrypted-payload-data"))
	payload := map[string]any{
		"content_summary":   "[加密消息]",
		"encrypted_content": encryptedContent,
		"encryption_metadata": map[string]any{
			"algorithm": "AES-256-GCM",
			"version":   1,
		},
	}

	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/encrypted", payload, memberLogin.Token)
	if err != nil {
		t.Fatalf("send encrypted message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("send encrypted message status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Message struct {
			ID               string `json:"id"`
			Content          string `json:"content"`
			EncryptedContent string `json:"encrypted_content"`
		} `json:"message"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result.Message.ID == "" {
		t.Fatal("expected message.id to be set")
	}
	// 加密消息应该包含 encrypted_content 或 content 为占位文本
	if result.Message.EncryptedContent == "" && result.Message.Content == "" {
		t.Fatal("expected encrypted_content or content to be set")
	}
}

func TestSendEncryptedMessage_NotMember(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	outsider := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	outsiderLogin := testutil.Login(t, c, outsider.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "e2ee-private-"+time.Now().Format("150405"), []string{member.ID})

	// 非成员尝试发送加密消息
	payload := map[string]any{
		"encrypted_content": base64.StdEncoding.EncodeToString([]byte("data")),
	}

	resp, _, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/encrypted", payload, outsiderLogin.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403, got %d", resp.StatusCode)
	}
}

func TestSendEncryptedMessage_MissingEncryptedContent(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	ownerLogin := testutil.Login(t, c, owner.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "e2ee-missing-"+time.Now().Format("150405"), []string{member.ID})

	// 缺少 encrypted_content
	payload := map[string]any{
		"content_summary": "[加密消息]",
	}

	resp, _, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/encrypted", payload, ownerLogin.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	// 应该返回 400 或 422
	if resp.StatusCode != 400 && resp.StatusCode != 422 {
		t.Fatalf("expected 400 or 422, got %d", resp.StatusCode)
	}
}
