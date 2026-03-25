package user

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/session"
	"desktop-el-core/internal/state"
)

func TestServiceUpdateMeStoresCurrentUser(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users/me" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPatch {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var body map[string]string
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request body failed: %v", err)
		}
		if body["nickname"] != "Alice" {
			t.Fatalf("unexpected request body: %+v", body)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"id":       "u-1",
				"username": "alice",
				"email":    "alice@example.com",
				"nickname": "Alice",
				"status":   "active",
			},
		})
	}))
	defer server.Close()

	sessionService := session.New()
	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}), sessionService)

	if _, err := service.UpdateMe(context.Background(), UpdateMeParams{Nickname: "Alice"}); err != nil {
		t.Fatalf("update me failed: %v", err)
	}

	currentUser := sessionService.CurrentUser()
	if currentUser == nil || currentUser.ID != "u-1" {
		t.Fatalf("expected current user to be stored, got: %+v", currentUser)
	}
	if currentUser.Nickname == nil || *currentUser.Nickname != "Alice" {
		t.Fatalf("unexpected stored nickname: %+v", currentUser)
	}
}

func TestServiceUpdateMePreservesCurrentUserWhenResponseDataIsNull(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data":    nil,
		})
	}))
	defer server.Close()

	sessionService := session.New()
	sessionService.SetCurrentUser(state.UserSnapshot{
		ID:       "u-existing",
		Username: "alice",
		Email:    "alice@example.com",
		Status:   "active",
	})
	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}), sessionService)

	if _, err := service.UpdateMe(context.Background(), UpdateMeParams{Nickname: "Alice"}); err != nil {
		t.Fatalf("update me failed: %v", err)
	}

	currentUser := sessionService.CurrentUser()
	if currentUser == nil {
		t.Fatalf("expected current user to be preserved")
	}
	if currentUser.ID != "u-existing" {
		t.Fatalf("expected existing user to be preserved, got: %+v", currentUser)
	}
}

func TestServiceSearchUsersSendsKeywordAndLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users/search" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.URL.Query().Get("keyword"); got != "alice" {
			t.Fatalf("unexpected keyword: %s", got)
		}
		if got := r.URL.Query().Get("limit"); got != "20" {
			t.Fatalf("unexpected limit: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data":    []any{},
		})
	}))
	defer server.Close()

	sessionService := session.New()
	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}), sessionService)

	if _, err := service.SearchUsers(context.Background(), SearchUsersParams{
		Keyword: "alice",
		Limit:   20,
	}); err != nil {
		t.Fatalf("search users failed: %v", err)
	}
}
