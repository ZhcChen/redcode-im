package testutil

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"sync"
)

var ensureDefaultStorageProviderOnce sync.Once
var ensureDefaultStorageProviderErr error

func EnsureDefaultStorageProvider(t TestingT, c *Client) {
	t.Helper()
	ensureDefaultStorageProviderOnce.Do(func() {
		ensureDefaultStorageProviderErr = ensureDefaultStorageProvider(c)
	})
	if ensureDefaultStorageProviderErr != nil {
		t.Fatalf("ensure default storage provider failed: %v", ensureDefaultStorageProviderErr)
	}
}

func ensureDefaultStorageProvider(c *Client) error {
	loginResult, err := adminLogin(c)
	if err != nil {
		return err
	}

	defaultReq := NewAuthedJSONRequestWithToken(http.MethodGet, c.BaseURL+"/api/admin/storage-providers/default", loginResult.Token, nil)
	defaultResp, err := c.HTTP.Do(defaultReq)
	if err != nil {
		return err
	}
	defaultResp.Body.Close()
	if defaultResp.StatusCode == http.StatusOK {
		return nil
	}

	createPayload := map[string]any{
		"provider_type": "tencent_cos",
		"name":          "mock-cos-default",
		"secret_id":     "mock-secret-id",
		"secret_key":    "mock-secret-key",
		"region":        "ap-shanghai",
		"endpoint":      "external-mock:19080",
		"bucket_name":   "mock-bucket",
		"is_active":     true,
		"is_default":    true,
		"description":   "mock provider for integration tests",
	}
	createReq := NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/api/admin/storage-providers", loginResult.Token, createPayload)
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		return err
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		return &simpleError{msg: "create default storage provider failed: " + string(body)}
	}

	return nil
}

func AdminLogin(t TestingT, c *Client) LoginResponse {
	t.Helper()
	loginResult, err := adminLogin(c)
	if err != nil {
		t.Fatalf("admin login failed: %v", err)
	}
	return loginResult
}

func adminLogin(c *Client) (LoginResponse, error) {
	initResp, _ := c.HTTP.Post(c.BaseURL+"/api/admin/init-default-admin", "application/json", bytes.NewReader([]byte("{}")))
	if initResp != nil {
		_ = initResp.Body.Close()
	}

	loginPayload := map[string]any{
		"username": "admin",
		"password": "admin123",
	}
	raw, _ := json.Marshal(loginPayload)
	loginResp, err := c.HTTP.Post(c.BaseURL+"/auth/admin/login", "application/json", bytes.NewReader(raw))
	if err != nil {
		return LoginResponse{}, err
	}
	defer loginResp.Body.Close()
	if loginResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(loginResp.Body)
		return LoginResponse{}, &simpleError{msg: "admin login failed: " + string(body)}
	}

	var loginResult LoginResponse
	if err := json.NewDecoder(loginResp.Body).Decode(&loginResult); err != nil {
		return LoginResponse{}, err
	}
	if loginResult.Token == "" {
		return LoginResponse{}, &simpleError{msg: "admin token empty"}
	}
	return loginResult, nil
}

func NewAuthedJSONRequestWithToken(method, url, token string, body any) *http.Request {
	var reader io.Reader
	if body != nil {
		raw, _ := json.Marshal(body)
		reader = bytes.NewReader(raw)
	}
	req, _ := http.NewRequest(method, url, reader)
	req.Header.Set("Authorization", "Bearer "+token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return req
}

type simpleError struct {
	msg string
}

func (e *simpleError) Error() string {
	return e.msg
}
