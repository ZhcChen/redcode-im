package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/session"
)

func TestServiceLoginStoresTokens(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/login" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"token":         "access-token",
				"refresh_token": "refresh-token",
				"user": map[string]any{
					"id":       "u-1",
					"username": "13800000000",
					"email":    "demo@example.com",
					"status":   "active",
				},
			},
		})
	}))
	defer server.Close()

	sessionService := session.New()
	client := httpclient.New(httpclient.Config{BaseURL: server.URL})
	service := New(client, sessionService)

	response, err := service.Login(context.Background(), LoginParams{
		Username: "13800000000",
		Password: "secret",
	})
	if err != nil {
		t.Fatalf("login failed: %v", err)
	}
	if response.Token != "access-token" {
		t.Fatalf("unexpected token: %+v", response)
	}
	if sessionService.AccessToken() != "access-token" {
		t.Fatalf("expected session access token to be stored")
	}
	if sessionService.RefreshToken() != "refresh-token" {
		t.Fatalf("expected session refresh token to be stored")
	}
}
