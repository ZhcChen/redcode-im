package testutil

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"os"
	"strings"
	"time"
)

type UserInfo struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	Email    string  `json:"email"`
	Nickname *string `json:"nickname"`
}

type LoginResponse struct {
	Token        string   `json:"token"`
	RefreshToken string   `json:"refresh_token"`
	User         UserInfo `json:"user"`
}

func UniqueUsername(prefix string) string {
	_ = prefix
	// 后端在某些环境会开启“手机号用户名”校验，这里统一生成合法手机号格式，
	// 并使用随机值避免跨测试轮次（持久化数据库）产生重复用户名。
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000_000))
	if err != nil {
		// 随机源异常时，降级为时间戳+进程号组合，尽量避免重复用户名冲突。
		fallback := (time.Now().UnixNano() + int64(os.Getpid())) % 1_000_000_000
		if fallback < 0 {
			fallback = -fallback
		}
		return fmt.Sprintf("13%09d", fallback)
	}
	return fmt.Sprintf("13%09d", n.Int64())
}

func UniqueEmail(prefix string) string {
	return fmt.Sprintf("%s_%s@example.test", sanitizeEmailLocal(prefix), UniqueUsername(prefix))
}

func sanitizeEmailLocal(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return "user"
	}
	var b strings.Builder
	for _, r := range value {
		switch {
		case r >= 'a' && r <= 'z':
			b.WriteRune(r)
		case r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '.' || r == '_' || r == '-':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}
	out := strings.Trim(b.String(), "._-")
	if out == "" {
		return "user"
	}
	return out
}

func RegisterUser(t TestingT, c *Client, account, password string) UserInfo {
	t.Helper()

	email := account
	if !strings.Contains(email, "@") {
		email = fmt.Sprintf("%s@example.test", account)
	}

	payload := map[string]any{
		"email":    email,
		"password": password,
		"nickname": email,
	}
	raw, _ := json.Marshal(payload)

	resp, err := c.HTTP.Post(c.BaseURL+"/auth/register", "application/json", bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("register request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("register expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var user UserInfo
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		t.Fatalf("decode register response failed: %v", err)
	}
	if user.ID == "" || user.Username == "" || user.Email == "" {
		t.Fatalf("invalid register response: %+v", user)
	}
	return user
}

func LoginWithPassword(t TestingT, c *Client, account, password string) LoginResponse {
	t.Helper()

	email := account
	if !strings.Contains(email, "@") {
		email = fmt.Sprintf("%s@example.test", account)
	}

	payload := map[string]any{
		"email":    email,
		"password": password,
	}
	raw, _ := json.Marshal(payload)

	resp, err := c.HTTP.Post(c.BaseURL+"/auth/login", "application/json", bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("login request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("login expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var loginResp LoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil {
		t.Fatalf("decode login response failed: %v", err)
	}
	if loginResp.Token == "" || loginResp.User.ID == "" || loginResp.RefreshToken == "" {
		t.Fatalf("invalid login response: %+v", loginResp)
	}
	return loginResp
}

func RefreshToken(t TestingT, c *Client, refreshToken string) LoginResponse {
	t.Helper()

	payload := map[string]any{
		"refresh_token": refreshToken,
	}
	raw, _ := json.Marshal(payload)

	resp, err := c.HTTP.Post(c.BaseURL+"/auth/refresh", "application/json", bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("refresh request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("refresh expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var loginResp LoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil {
		t.Fatalf("decode refresh response failed: %v", err)
	}
	if loginResp.Token == "" || loginResp.RefreshToken == "" || loginResp.User.ID == "" {
		t.Fatalf("invalid refresh response: %+v", loginResp)
	}
	return loginResp
}

func NewAuthedJSONRequest(t TestingT, method, url, token string, body any) *http.Request {
	t.Helper()

	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body failed: %v", err)
		}
		reader = bytes.NewReader(raw)
	}

	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		t.Fatalf("new request failed: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return req
}

type TestingT interface {
	Helper()
	Fatalf(format string, args ...any)
}
