package auth_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type mockTokenResponse struct {
	IDToken string `json:"id_token"`
}

type oauthLoginRequest struct {
	Provider string `json:"provider"`
	IDToken  string `json:"id_token"`
}

type oauthLoginResponse struct {
	Token string `json:"token"`
	User  struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
}

func mintMockIDToken(t *testing.T, provider, subPrefix string) string {
	t.Helper()

	mockBase := testutil.ExternalMockBaseURL()
	endpoint := "/mock/google/id-token"
	aud := "mock-google-client-id"
	if provider == "apple" {
		endpoint = "/mock/apple/id-token"
		aud = "mock-apple-client-id"
	}

	payload := map[string]any{
		"sub":   fmt.Sprintf("%s-%d", subPrefix, time.Now().UnixNano()),
		"email": fmt.Sprintf("%s_%d@example.com", subPrefix, time.Now().UnixNano()),
		"name":  "Mock OAuth User",
		"aud":   aud,
	}
	body, _ := json.Marshal(payload)

	resp, err := http.Post(mockBase+endpoint, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("mint mock %s id_token failed: %v", provider, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		data, _ := io.ReadAll(resp.Body)
		t.Fatalf("mint mock %s id_token expect 200, got %d: %s", provider, resp.StatusCode, string(data))
	}

	var result mockTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode mock %s id_token response failed: %v", provider, err)
	}
	if result.IDToken == "" {
		t.Fatalf("mock %s id_token empty", provider)
	}

	return result.IDToken
}

func doOAuthLogin(t *testing.T, provider string, idToken string) oauthLoginResponse {
	t.Helper()

	client := testutil.NewClient()
	payload := oauthLoginRequest{
		Provider: provider,
		IDToken:  idToken,
	}
	body, _ := json.Marshal(payload)

	resp, err := client.HTTP.Post(client.BaseURL+"/auth/login/oauth", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("oauth login request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		data, _ := io.ReadAll(resp.Body)
		t.Fatalf("oauth login expect 200, got %d: %s", resp.StatusCode, string(data))
	}

	var result oauthLoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode oauth login response failed: %v", err)
	}
	if result.Token == "" || result.User.Username == "" || result.User.ID == "" {
		t.Fatalf("oauth login response missing required fields: %+v", result)
	}

	return result
}

func TestOAuthLogin_Google_OK(t *testing.T) {
	idToken := mintMockIDToken(t, "google", "google-user")
	_ = doOAuthLogin(t, "google", idToken)
}

func TestOAuthLogin_Apple_OK(t *testing.T) {
	idToken := mintMockIDToken(t, "apple", "apple-user")
	_ = doOAuthLogin(t, "apple", idToken)
}
