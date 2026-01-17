package testutil

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"testing"
)

type UserInfo struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type LoginResponse struct {
	Token        string   `json:"token"`
	RefreshToken string   `json:"refresh_token"`
	User         UserInfo `json:"user"`
}

func UniquePhone() string {
	// 1[3-9]XXXXXXXXX
	var n uint64
	_ = binary.Read(rand.Reader, binary.LittleEndian, &n)
	randPart := n % 1_000_000_000
	return fmt.Sprintf("13%09d", randPart)
}

func RegisterUser(t *testing.T, c *Client, username, password string) UserInfo {
	t.Helper()
	payload := map[string]any{
		"username": username,
		"password": password,
		"email":    username + "@example.com",
		"nickname": username,
	}
	resp, body, err := c.DoJSON("POST", "/auth/register", payload, "")
	if err != nil {
		t.Fatalf("register user http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("register user status=%d body=%s", resp.StatusCode, string(body))
	}
	var ui UserInfo
	if err := DecodeJSON(body, &ui); err != nil {
		t.Fatalf("register decode: %v body=%s", err, string(body))
	}
	return ui
}

func Login(t *testing.T, c *Client, username, password string) LoginResponse {
	t.Helper()
	payload := map[string]any{
		"username": username,
		"password": password,
	}
	resp, body, err := c.DoJSON("POST", "/auth/login", payload, "")
	if err != nil {
		t.Fatalf("login http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("login status=%d body=%s", resp.StatusCode, string(body))
	}
	var lr LoginResponse
	if err := DecodeJSON(body, &lr); err != nil {
		t.Fatalf("login decode: %v body=%s", err, string(body))
	}
	return lr
}

func AdminLogin(t *testing.T, c *Client, username, password string) LoginResponse {
	t.Helper()
	payload := map[string]any{
		"username": username,
		"password": password,
	}
	resp, body, err := c.DoJSON("POST", "/auth/admin/login", payload, "")
	if err != nil {
		t.Fatalf("admin login http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("admin login status=%d body=%s", resp.StatusCode, string(body))
	}
	var lr LoginResponse
	if err := DecodeJSON(body, &lr); err != nil {
		t.Fatalf("admin login decode: %v body=%s", err, string(body))
	}
	return lr
}

// EnsureDefaultAdmin 尽力而为地初始化默认管理员账号（仅测试环境可用）。
func EnsureDefaultAdmin(t *testing.T, c *Client) {
	t.Helper()
	_, _, _ = c.DoJSON("POST", "/api/admin/init-default-admin", map[string]any{}, "")
}
