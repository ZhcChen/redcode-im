package httpclient

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClientDoInjectsBearerTokenAndQuery(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}
		if got := r.URL.Query().Get("keyword"); got != "chat" {
			t.Fatalf("unexpected query keyword: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"items": 3,
			},
		})
	}))
	defer server.Close()

	client := New(Config{
		BaseURL: server.URL,
	})
	client.SetToken("access-token")

	response, err := client.Do(context.Background(), Request{
		Method: "GET",
		Path:   "/search",
		Query: map[string]string{
			"keyword": "chat",
		},
	})
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if !response.Success || response.Code != 200 {
		t.Fatalf("unexpected response envelope: %+v", response)
	}
}

func TestClientDoWrapsRawJSONSuccessBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"has_update":true,"version":{"id":"v-1"}}`))
	}))
	defer server.Close()

	client := New(Config{BaseURL: server.URL})
	response, err := client.Do(context.Background(), Request{
		Method: http.MethodGet,
		Path:   "/versions/latest",
	})
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if !response.Success || response.Code != http.StatusOK {
		t.Fatalf("unexpected wrapped response: %+v", response)
	}
	if len(response.Data) == 0 || string(response.Data) == "null" {
		t.Fatalf("expected raw json body to be wrapped into data: %+v", response)
	}
}

func TestClientDoWrapsEmptyUnauthorizedResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	client := New(Config{BaseURL: server.URL})
	response, err := client.Do(context.Background(), Request{
		Method: http.MethodGet,
		Path:   "/auth/me",
	})
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if response.Success {
		t.Fatalf("expected unauthorized response to be wrapped as failure: %+v", response)
	}
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("unexpected unauthorized code: %+v", response)
	}
	if response.Message != http.StatusText(http.StatusUnauthorized) {
		t.Fatalf("unexpected unauthorized message: %+v", response)
	}
}
