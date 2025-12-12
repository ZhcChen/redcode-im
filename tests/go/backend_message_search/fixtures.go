package backend_message_search

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"testing"
)

type loginResponse struct {
	Token string `json:"token"`
	User  struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
}

type userInfo struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

func registerUser(t *testing.T, c *Client, username, password string) userInfo {
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
	var ui userInfo
	if err := Decode(body, &ui); err != nil {
		t.Fatalf("register decode: %v body=%s", err, string(body))
	}
	return ui
}

func login(t *testing.T, c *Client, username, password string) loginResponse {
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
	var lr loginResponse
	if err := Decode(body, &lr); err != nil {
		t.Fatalf("login decode: %v body=%s", err, string(body))
	}
	return lr
}

func uniquePhone() string {
	// 1[3-9]XXXXXXXXX
	var n uint64
	_ = binary.Read(rand.Reader, binary.LittleEndian, &n)
	randPart := n % 1_000_000_000
	return fmt.Sprintf("13%09d", randPart)
}

