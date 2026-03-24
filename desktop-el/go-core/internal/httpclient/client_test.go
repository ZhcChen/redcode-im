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

func TestClientDoPreservesTopLevelSuccessBodyWithoutDataField(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"success":true,"message":"生成附件下载链接成功","download_url":"https://download.example.com/file.pdf"}`))
	}))
	defer server.Close()

	client := New(Config{BaseURL: server.URL})
	response, err := client.Do(context.Background(), Request{
		Method: http.MethodGet,
		Path:   "/rooms/room-1/messages/attachments/download",
	})
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if !response.Success || response.Code != http.StatusOK {
		t.Fatalf("unexpected response envelope: %+v", response)
	}
	if len(response.Data) == 0 || string(response.Data) == "null" {
		t.Fatalf("expected top-level success body to be preserved in data: %+v", response)
	}

	var payload map[string]any
	if err := json.Unmarshal(response.Data, &payload); err != nil {
		t.Fatalf("decode preserved data failed: %v", err)
	}
	if payload["download_url"] != "https://download.example.com/file.pdf" {
		t.Fatalf("unexpected preserved payload: %+v", payload)
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
