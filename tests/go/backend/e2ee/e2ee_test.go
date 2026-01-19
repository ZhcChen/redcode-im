package e2ee_test

import (
	"encoding/base64"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 生成32字节的测试密钥（base64编码）
func genKey32() string {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	return base64.StdEncoding.EncodeToString(key)
}

// 生成64字节的签名（base64编码）
func genSig64() string {
	sig := make([]byte, 64)
	for i := range sig {
		sig[i] = byte(i)
	}
	return base64.StdEncoding.EncodeToString(sig)
}

func TestUploadKeyBundle_Success(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	payload := map[string]any{
		"device_id":    "test-device-001",
		"identity_key": genKey32(),
		"signed_pre_key": map[string]any{
			"key_id":     1,
			"public_key": genKey32(),
			"signature":  genSig64(),
		},
		"one_time_pre_keys": []map[string]any{
			{"key_id": 1, "public_key": genKey32()},
			{"key_id": 2, "public_key": genKey32()},
			{"key_id": 3, "public_key": genKey32()},
		},
	}

	resp, body, err := c.DoJSON("POST", "/e2ee/keys/bundle", payload, login.Token)
	if err != nil {
		t.Fatalf("upload key bundle http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("upload key bundle status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Success             bool   `json:"success"`
		DeviceID            string `json:"device_id"`
		OneTimePreKeysSaved int    `json:"one_time_pre_keys_saved"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !result.Success {
		t.Fatal("expected success=true")
	}
	if result.DeviceID != "test-device-001" {
		t.Fatalf("expected device_id=test-device-001, got %s", result.DeviceID)
	}
	if result.OneTimePreKeysSaved != 3 {
		t.Fatalf("expected 3 one_time_pre_keys_saved, got %d", result.OneTimePreKeysSaved)
	}
}

func TestUploadKeyBundle_InvalidIdentityKey(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	// identity_key 长度不是 32 字节
	payload := map[string]any{
		"device_id":    "test-device-002",
		"identity_key": base64.StdEncoding.EncodeToString([]byte("short")),
		"signed_pre_key": map[string]any{
			"key_id":     1,
			"public_key": genKey32(),
			"signature":  genSig64(),
		},
		"one_time_pre_keys": []map[string]any{},
	}

	resp, _, err := c.DoJSON("POST", "/e2ee/keys/bundle", payload, login.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestGetKeyBundles_Success(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	// 用户A上传密钥
	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	loginA := testutil.Login(t, c, userA.Username, pass)

	payload := map[string]any{
		"device_id":    "device-a",
		"identity_key": genKey32(),
		"signed_pre_key": map[string]any{
			"key_id":     1,
			"public_key": genKey32(),
			"signature":  genSig64(),
		},
		"one_time_pre_keys": []map[string]any{
			{"key_id": 1, "public_key": genKey32()},
		},
	}
	resp, body, err := c.DoJSON("POST", "/e2ee/keys/bundle", payload, loginA.Token)
	if err != nil || resp.StatusCode != 200 {
		t.Fatalf("upload failed: status=%d body=%s", resp.StatusCode, string(body))
	}

	// 用户B获取用户A的密钥包
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	resp, body, err = c.DoJSON("GET", "/e2ee/users/"+userA.ID+"/key-bundles", nil, loginB.Token)
	if err != nil {
		t.Fatalf("get key bundles http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get key bundles status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		UserID  string `json:"user_id"`
		Devices []struct {
			DeviceID    string `json:"device_id"`
			IdentityKey string `json:"identity_key"`
		} `json:"devices"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result.UserID != userA.ID {
		t.Fatalf("expected user_id=%s, got %s", userA.ID, result.UserID)
	}
	if len(result.Devices) == 0 {
		t.Fatal("expected at least one device")
	}
}

func TestGetKeyBundles_UserNotInitialized(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	// 用户A没有上传密钥
	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	// 用户B尝试获取用户A的密钥包
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	resp, _, err := c.DoJSON("GET", "/e2ee/users/"+userA.ID+"/key-bundles", nil, loginB.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	// 应该返回 404
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}
