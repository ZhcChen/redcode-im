package app

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"desktop-el-core/internal/auth"
	"desktop-el-core/internal/bootstrap"
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/eventbus"
	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/rpc"
	"desktop-el-core/internal/state"

	"github.com/gorilla/websocket"
)

func TestAppRegistersBootstrapRPCAndEmitsSnapshotEvent(t *testing.T) {
	var stdout bytes.Buffer

	application := New(
		config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			APIBaseURL:  "http://127.0.0.1:8010",
			WSURL:       "ws://127.0.0.1:8010/ws",
			AppVersion:  "0.1.0",
			BuildNumber: 1,
			Channel:     "stable",
			FeatureFlags: map[string]bool{
				"desktop_el": true,
			},
		},
		eventbus.New(),
		bootstrap.New(config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			APIBaseURL:  "http://127.0.0.1:8010",
			WSURL:       "ws://127.0.0.1:8010/ws",
			AppVersion:  "0.1.0",
			BuildNumber: 1,
			Channel:     "stable",
			FeatureFlags: map[string]bool{
				"desktop_el": true,
			},
		}),
		rpc.NewEncoder(&stdout),
	)

	server := application.RegisterRPC()

	response := server.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-bootstrap-1",
		Method: "core.bootstrap.get",
	})
	if response.Error != nil {
		t.Fatalf("expected bootstrap request to succeed, got: %+v", response.Error)
	}

	var snapshot map[string]any
	if err := json.Unmarshal(response.Result, &snapshot); err != nil {
		t.Fatalf("decode bootstrap result failed: %v", err)
	}
	if snapshot["feature_flags"] == nil {
		t.Fatalf("expected feature_flags in bootstrap snapshot: %+v", snapshot)
	}

	if err := application.EmitBootstrapSnapshot(context.Background()); err != nil {
		t.Fatalf("emit bootstrap snapshot failed: %v", err)
	}

	var event rpc.Event
	if err := json.Unmarshal(bytes.TrimSpace(stdout.Bytes()), &event); err != nil {
		t.Fatalf("decode emitted event failed: %v", err)
	}
	if event.Event != "core.bootstrap.snapshot" {
		t.Fatalf("unexpected emitted event: %+v", event)
	}
}

func TestAppAuthLoginReturnsEnvelopeAndStoresSession(t *testing.T) {
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

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()

	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-login-success",
		Method: "auth.login",
		Params: mustJSONRaw(map[string]any{
			"username": "13800000000",
			"password": "secret",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected login request to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode login response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 || envelope.Message != "ok" {
		t.Fatalf("unexpected login envelope: %+v", envelope)
	}

	var result auth.LoginResponse
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode login data failed: %v", err)
	}
	if result.Token != "access-token" {
		t.Fatalf("unexpected login token: %+v", result)
	}
	if application.session.AccessToken() != "access-token" {
		t.Fatalf("expected session access token to be stored")
	}
	if application.session.RefreshToken() != "refresh-token" {
		t.Fatalf("expected session refresh token to be stored")
	}
	currentUser := application.session.CurrentUser()
	if currentUser == nil || currentUser.ID != "u-1" {
		t.Fatalf("expected current user snapshot to be stored, got: %+v", currentUser)
	}
}

func TestAppAuthLoginPreservesFailureEnvelopeAndDoesNotStoreSession(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": false,
			"code":    401,
			"message": "invalid credentials",
			"data":    nil,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()

	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-login-failure",
		Method: "auth.login",
		Params: mustJSONRaw(map[string]any{
			"username": "13800000000",
			"password": "wrong-password",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected login failure to stay in envelope, got rpc error: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode failed login response failed: %v", err)
	}
	if envelope.Success {
		t.Fatalf("expected failed login envelope, got: %+v", envelope)
	}
	if envelope.Code != 401 || envelope.Message != "invalid credentials" {
		t.Fatalf("unexpected failed login envelope: %+v", envelope)
	}
	if application.session.AccessToken() != "" || application.session.RefreshToken() != "" {
		t.Fatalf("expected failed login not to mutate session")
	}
}

func TestAppAuthMeGetReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"id":       "u-1",
				"username": "13800000000",
				"email":    "demo@example.com",
				"status":   "active",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-me",
		Method: "auth.me.get",
	})
	if response.Error != nil {
		t.Fatalf("expected auth.me.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode current user response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected current user envelope: %+v", envelope)
	}
}

func TestAppBootstrapGetIncludesCurrentAuthSnapshot(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()

	loginResponse := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-login-bootstrap",
		Method: "auth.login",
		Params: mustJSONRaw(map[string]any{
			"username": "13800000000",
			"password": "secret",
		}),
	})
	if loginResponse.Error != nil {
		t.Fatalf("expected login request to succeed, got: %+v", loginResponse.Error)
	}

	bootstrapResponse := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-bootstrap-auth",
		Method: "core.bootstrap.get",
	})
	if bootstrapResponse.Error != nil {
		t.Fatalf("expected bootstrap request to succeed, got: %+v", bootstrapResponse.Error)
	}

	var snapshot map[string]any
	if err := json.Unmarshal(bootstrapResponse.Result, &snapshot); err != nil {
		t.Fatalf("decode bootstrap result failed: %v", err)
	}

	authSnapshot, ok := snapshot["auth"].(map[string]any)
	if !ok {
		t.Fatalf("expected auth snapshot in bootstrap result, got: %+v", snapshot)
	}
	if authSnapshot["logged_in"] != true {
		t.Fatalf("expected logged_in to be true, got: %+v", authSnapshot)
	}

	currentUser, ok := authSnapshot["current_user"].(map[string]any)
	if !ok {
		t.Fatalf("expected current_user in auth snapshot, got: %+v", authSnapshot)
	}
	if currentUser["id"] != "u-1" {
		t.Fatalf("unexpected current user snapshot: %+v", currentUser)
	}
}

func TestAppAuthLogoutClearsSessionAndBootstrapAuthSnapshot(t *testing.T) {
	application := newTestApp("http://127.0.0.1:8010")
	application.session.Set("access-token", "refresh-token")
	application.session.SetCurrentUser(state.UserSnapshot{
		ID:       "u-1",
		Username: "13800000000",
		Email:    "demo@example.com",
		Status:   "active",
	})
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	logoutResponse := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-logout",
		Method: "auth.logout",
	})
	if logoutResponse.Error != nil {
		t.Fatalf("expected auth.logout to succeed, got: %+v", logoutResponse.Error)
	}

	if application.session.AccessToken() != "" || application.session.RefreshToken() != "" {
		t.Fatalf("expected auth.logout to clear session tokens")
	}
	if application.session.CurrentUser() != nil {
		t.Fatalf("expected auth.logout to clear current user snapshot")
	}
	if application.httpClient.AccessToken() != "" {
		t.Fatalf("expected auth.logout to clear http client token")
	}

	bootstrapResponse := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-bootstrap-post-logout",
		Method: "core.bootstrap.get",
	})
	if bootstrapResponse.Error != nil {
		t.Fatalf("expected bootstrap request to succeed, got: %+v", bootstrapResponse.Error)
	}

	var snapshot map[string]any
	if err := json.Unmarshal(bootstrapResponse.Result, &snapshot); err != nil {
		t.Fatalf("decode bootstrap result failed: %v", err)
	}

	authSnapshot, ok := snapshot["auth"].(map[string]any)
	if !ok {
		t.Fatalf("expected auth snapshot in bootstrap result, got: %+v", snapshot)
	}
	if authSnapshot["logged_in"] != false {
		t.Fatalf("expected logged_in to be false after logout, got: %+v", authSnapshot)
	}
	if authSnapshot["current_user"] != nil {
		t.Fatalf("expected current_user to be nil after logout, got: %+v", authSnapshot)
	}
}

func TestAppVersionLatestUsesProvidedPlatform(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/versions/latest" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if got := r.URL.Query().Get("platform"); got != "linux" {
			t.Fatalf("unexpected platform query: %s", got)
		}
		if got := r.URL.Query().Get("channel"); got != "nightly" {
			t.Fatalf("unexpected channel query: %s", got)
		}
		if got := r.URL.Query().Get("current_version"); got != "1.2.3" {
			t.Fatalf("unexpected current_version query: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"has_update": true,
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-version-latest",
		Method: "version.latest.get",
		Params: mustJSONRaw(map[string]any{
			"platform":        "linux",
			"channel":         "nightly",
			"current_version": "1.2.3",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected version.latest.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode latest version response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected latest version envelope: %+v", envelope)
	}
}

func TestAppAuthRegisterReturnsWrappedUserInfo(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/register" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":         "u-2",
			"username":   "13800138000",
			"email":      "13800138000@example.com",
			"nickname":   "测试用户",
			"avatar_url": nil,
			"status":     "active",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-auth-register",
		Method: "auth.register",
		Params: mustJSONRaw(map[string]any{
			"username": "13800138000",
			"email":    "13800138000@example.com",
			"password": "Test123456",
			"nickname": "测试用户",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected auth.register to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode register response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected register envelope: %+v", envelope)
	}

	var user auth.BackendUser
	if err := json.Unmarshal(envelope.Data, &user); err != nil {
		t.Fatalf("decode register data failed: %v", err)
	}
	if user.ID != "u-2" || user.Username != "13800138000" {
		t.Fatalf("unexpected registered user: %+v", user)
	}
}

func TestAppSettingsCaptchaGetReturnsWrappedPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/settings/captcha" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"require_captcha_for_login": true,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-settings-captcha",
		Method: "settings.captcha.get",
	})
	if response.Error != nil {
		t.Fatalf("expected settings.captcha.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode captcha response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected captcha envelope: %+v", envelope)
	}
}

func TestAppSettingsPrivacyGetReturnsWrappedDocument(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/settings/privacy-policy" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"key":        "privacy_policy",
			"title":      "隐私协议",
			"content":    "<p>内容</p>",
			"updated_at": "2026-03-24T00:00:00Z",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-settings-privacy",
		Method: "settings.privacy.get",
	})
	if response.Error != nil {
		t.Fatalf("expected settings.privacy.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode privacy response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected privacy envelope: %+v", envelope)
	}
}

func TestAppSettingsGeneralGetReturnsWrappedPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/settings/general" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"app_name": "Chatly",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-settings-general",
		Method: "settings.general.get",
	})
	if response.Error != nil {
		t.Fatalf("expected settings.general.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode general settings response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected general settings envelope: %+v", envelope)
	}
}

func TestAppUserMeUpdateReturnsWrappedUserInfoAndUpdatesSessionSnapshot(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users/me" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPatch {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["nickname"] != "新的昵称" {
			t.Fatalf("unexpected nickname payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data": map[string]any{
				"id":         "u-1",
				"username":   "13800000000",
				"email":      "demo@example.com",
				"nickname":   "新的昵称",
				"avatar_url": nil,
				"status":     "active",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.session.SetCurrentUser(state.UserSnapshot{
		ID:       "u-1",
		Username: "13800000000",
		Email:    "demo@example.com",
		Status:   "active",
	})
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-user-update",
		Method: "user.me.update",
		Params: mustJSONRaw(map[string]any{
			"nickname": "新的昵称",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected user.me.update to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode user update response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected user update envelope: %+v", envelope)
	}

	currentUser := application.session.CurrentUser()
	if currentUser == nil || currentUser.Nickname == nil || *currentUser.Nickname != "新的昵称" {
		t.Fatalf("expected current user snapshot nickname to be updated, got: %+v", currentUser)
	}
}

func TestAppFriendListReturnsWrappedPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"id": "friend-1",
				"user": map[string]any{
					"id":         "u-2",
					"username":   "alice",
					"email":      "alice@example.com",
					"nickname":   "Alice",
					"avatar_url": nil,
					"status":     "active",
				},
				"created_at":    "2026-03-24T00:00:00Z",
				"friend_remark": "同事",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-list",
		Method: "friend.list",
	})
	if response.Error != nil {
		t.Fatalf("expected friend.list to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.list response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.list envelope: %+v", envelope)
	}
}

func TestAppFriendRequestsListUsesQueryParams(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/requests" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if got := r.URL.Query().Get("direction"); got != "incoming" {
			t.Fatalf("unexpected direction query: %s", got)
		}
		if got := r.URL.Query().Get("status"); got != "pending" {
			t.Fatalf("unexpected status query: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"id": "request-1",
				"requester": map[string]any{
					"id":         "u-3",
					"username":   "bob",
					"email":      "bob@example.com",
					"nickname":   "Bob",
					"avatar_url": nil,
					"status":     "active",
				},
				"addressee": map[string]any{
					"id":         "u-1",
					"username":   "me",
					"email":      "me@example.com",
					"nickname":   "Me",
					"avatar_url": nil,
					"status":     "active",
				},
				"status":      "pending",
				"message":     "hi",
				"created_at":  "2026-03-24T00:00:00Z",
				"is_incoming": true,
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-requests-list",
		Method: "friend.requests.list",
		Params: mustJSONRaw(map[string]any{
			"direction": "incoming",
			"status":    "pending",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected friend.requests.list to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.requests.list response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.requests.list envelope: %+v", envelope)
	}
}

func TestAppFriendRequestRespondPostsAction(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/requests/request-1/respond" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["action"] != "accept" {
			t.Fatalf("unexpected action payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"id": "request-1",
			"requester": map[string]any{
				"id":       "u-3",
				"username": "bob",
				"email":    "bob@example.com",
				"nickname": "Bob",
				"status":   "active",
			},
			"addressee": map[string]any{
				"id":       "u-1",
				"username": "me",
				"email":    "me@example.com",
				"nickname": "Me",
				"status":   "active",
			},
			"status":       "accepted",
			"message":      "hi",
			"created_at":   "2026-03-24T00:00:00Z",
			"responded_at": "2026-03-24T00:05:00Z",
			"is_incoming":  true,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-respond",
		Method: "friend.request.respond",
		Params: mustJSONRaw(map[string]any{
			"request_id": "request-1",
			"action":     "accept",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected friend.request.respond to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.request.respond response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.request.respond envelope: %+v", envelope)
	}
}

func TestAppUserSearchUsesKeywordAndLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users/search" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}
		if got := r.URL.Query().Get("keyword"); got != "alice" {
			t.Fatalf("unexpected keyword query: %s", got)
		}
		if got := r.URL.Query().Get("limit"); got != "5" {
			t.Fatalf("unexpected limit query: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"id":         "u-2",
				"username":   "alice",
				"email":      "alice@example.com",
				"nickname":   "Alice",
				"avatar_url": nil,
				"status":     "active",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-user-search",
		Method: "user.search",
		Params: mustJSONRaw(map[string]any{
			"keyword": "alice",
			"limit":   5,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected user.search to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode user.search response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected user.search envelope: %+v", envelope)
	}
}

func TestAppFriendRequestCreatePostsTargetUserIDAndMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/requests" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["target_user_id"] != "u-2" {
			t.Fatalf("unexpected target_user_id payload: %+v", payload)
		}
		if payload["message"] != "你好，我是 Alice" {
			t.Fatalf("unexpected message payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"id": "request-2",
			"requester": map[string]any{
				"id":       "u-1",
				"username": "me",
				"email":    "me@example.com",
				"nickname": "Me",
				"status":   "active",
			},
			"addressee": map[string]any{
				"id":       "u-2",
				"username": "alice",
				"email":    "alice@example.com",
				"nickname": "Alice",
				"status":   "active",
			},
			"status":      "pending",
			"message":     "你好，我是 Alice",
			"created_at":  "2026-03-24T00:00:00Z",
			"is_incoming": false,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-request-create",
		Method: "friend.request.create",
		Params: mustJSONRaw(map[string]any{
			"target_user_id": "u-2",
			"message":        "你好，我是 Alice",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected friend.request.create to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.request.create response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.request.create envelope: %+v", envelope)
	}
}

func TestAppFriendRemarkUpdatePatchesRemark(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/u-2/remark" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPatch {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["remark"] != "Alice 同事" {
			t.Fatalf("unexpected remark payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"remark": "Alice 同事",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-remark-update",
		Method: "friend.remark.update",
		Params: mustJSONRaw(map[string]any{
			"friend_user_id": "u-2",
			"remark":         "Alice 同事",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected friend.remark.update to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.remark.update response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.remark.update envelope: %+v", envelope)
	}
}

func TestAppFriendDeleteDeletesFriendship(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/u-2" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodDelete {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "删除好友成功",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-friend-delete",
		Method: "friend.delete",
		Params: mustJSONRaw(map[string]any{
			"friend_user_id": "u-2",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected friend.delete to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode friend.delete response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected friend.delete envelope: %+v", envelope)
	}
}

func TestAppChatListReturnsWrappedPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/chats" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"room_id":               "room-1",
				"name":                  "Alice",
				"room_type":             "private",
				"avatar_url":            nil,
				"unread_count":          3,
				"notification_settings": 0,
				"is_muted":              false,
				"is_pinned":             true,
				"last_message": map[string]any{
					"id":              "msg-1",
					"content":         "最近一条消息",
					"message_type":    "text",
					"created_at":      "2026-03-24T00:00:00Z",
					"sender_id":       "u-2",
					"sender_username": "alice",
					"sender_nickname": "Alice",
				},
				"friend_user_id":  "u-2",
				"friend_nickname": "Alice",
				"friend_username": "alice",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-list",
		Method: "chat.list",
	})
	if response.Error != nil {
		t.Fatalf("expected chat.list to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.list response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.list envelope: %+v", envelope)
	}

	var chats []map[string]any
	if err := json.Unmarshal(envelope.Data, &chats); err != nil {
		t.Fatalf("decode chat.list data failed: %v", err)
	}
	if len(chats) != 1 {
		t.Fatalf("expected one chat summary, got: %+v", chats)
	}
	if chats[0]["room_id"] != "room-1" {
		t.Fatalf("unexpected chat summary payload: %+v", chats[0])
	}
}

func TestAppChatEnsurePrivatePostsFriendChat(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/u-2/chat" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"room_id":                  "room-2",
			"room_name":                "Alice",
			"room_type":                "private",
			"friend_id":                "u-2",
			"friend_name":              "Alice",
			"friend_avatar":            nil,
			"friend_avatar_object_key": nil,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-private-ensure",
		Method: "chat.private.ensure",
		Params: mustJSONRaw(map[string]any{
			"friend_user_id": "u-2",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.private.ensure to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.private.ensure response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.private.ensure envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.private.ensure data failed: %v", err)
	}
	if result["room_id"] != "room-2" {
		t.Fatalf("unexpected ensured chat payload: %+v", result)
	}
}

func TestAppChatCreateGroupPostsRooms(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request body failed: %v", err)
		}
		if body["name"] != "项目组" {
			t.Fatalf("unexpected room name: %+v", body)
		}
		memberIDs, ok := body["member_ids"].([]any)
		if !ok || len(memberIDs) != 2 {
			t.Fatalf("unexpected member_ids payload: %+v", body["member_ids"])
		}
		if memberIDs[0] != "u-2" || memberIDs[1] != "u-3" {
			t.Fatalf("unexpected member_ids order: %+v", memberIDs)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"room": map[string]any{
				"id":          "room-group-1",
				"name":        "项目组",
				"room_type":   "group",
				"description": "项目群",
				"owner_id":    "u-1",
				"avatar_url":  nil,
				"created_at":  "2026-03-25T12:00:00Z",
				"updated_at":  "2026-03-25T12:00:00Z",
				"deleted_at":  nil,
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-group-create",
		Method: "chat.group.create",
		Params: mustJSONRaw(map[string]any{
			"name":            "项目组",
			"member_user_ids": []string{"u-2", "u-3"},
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.group.create to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.group.create response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.group.create envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.group.create data failed: %v", err)
	}
	room, ok := result["room"].(map[string]any)
	if !ok {
		t.Fatalf("unexpected created room payload: %+v", result)
	}
	if room["id"] != "room-group-1" || room["name"] != "项目组" || room["room_type"] != "group" {
		t.Fatalf("unexpected created room data: %+v", room)
	}
}

func TestAppChatRoomGetReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-group-1" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"room": map[string]any{
				"id":                "room-group-1",
				"name":              "项目组",
				"description":       "项目群",
				"avatar_url":        nil,
				"avatar_object_key": "rooms/project/avatar.png",
				"room_type":         "group",
				"owner_id":          "u-1",
				"created_at":        "2026-03-25T12:00:00Z",
				"updated_at":        "2026-03-25T12:30:00Z",
				"deleted_at":        nil,
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-room-get",
		Method: "chat.room.get",
		Params: mustJSONRaw(map[string]any{
			"room_id": "room-group-1",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.room.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.room.get response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.room.get envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.room.get data failed: %v", err)
	}
	room, ok := result["room"].(map[string]any)
	if !ok {
		t.Fatalf("unexpected room detail payload: %+v", result)
	}
	if room["id"] != "room-group-1" || room["owner_id"] != "u-1" {
		t.Fatalf("unexpected room detail data: %+v", room)
	}
}

func TestAppChatRoomMembersListReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-group-1/members" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"user_id":           "u-1",
				"username":          "alice",
				"nickname":          "Alice",
				"avatar_url":        nil,
				"avatar_object_key": "avatars/u-1.png",
				"role":              "owner",
				"joined_at":         "2026-03-25T12:00:00Z",
			},
			{
				"user_id":    "u-2",
				"username":   "bob",
				"nickname":   "Bob",
				"avatar_url": nil,
				"role":       "member",
				"joined_at":  "2026-03-25T12:01:00Z",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-room-members-list",
		Method: "chat.room.members.list",
		Params: mustJSONRaw(map[string]any{
			"room_id": "room-group-1",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.room.members.list to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.room.members.list response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.room.members.list envelope: %+v", envelope)
	}

	var members []map[string]any
	if err := json.Unmarshal(envelope.Data, &members); err != nil {
		t.Fatalf("decode chat.room.members.list data failed: %v", err)
	}
	if len(members) != 2 || members[0]["role"] != "owner" || members[1]["user_id"] != "u-2" {
		t.Fatalf("unexpected room member list data: %+v", members)
	}
}

func TestAppChatGroupSettingsGetReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-group-1/settings" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"settings": map[string]any{
				"id":                           "settings-1",
				"room_id":                      "room-group-1",
				"join_approval_required":       true,
				"member_can_invite":            false,
				"member_can_add_friends":       true,
				"require_admin_to_add_friends": false,
				"max_members":                  500,
				"global_mute_enabled":          true,
				"global_mute_until":            "2026-03-26T12:00:00Z",
				"global_mute_reason":           "会议中",
				"global_mute_set_by":           "u-1",
				"created_at":                   "2026-03-25T12:00:00Z",
				"updated_at":                   "2026-03-25T12:30:00Z",
			},
			"my_mute": map[string]any{
				"is_muted":   true,
				"reason":     "临时禁言",
				"muted_at":   "2026-03-25T12:10:00Z",
				"mute_until": "2026-03-25T13:10:00Z",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-group-settings-get",
		Method: "chat.group.settings.get",
		Params: mustJSONRaw(map[string]any{
			"room_id": "room-group-1",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.group.settings.get to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.group.settings.get response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.group.settings.get envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.group.settings.get data failed: %v", err)
	}
	settings, ok := result["settings"].(map[string]any)
	if !ok {
		t.Fatalf("unexpected settings payload: %+v", result)
	}
	if settings["room_id"] != "room-group-1" || settings["global_mute_enabled"] != true {
		t.Fatalf("unexpected group settings data: %+v", settings)
	}
	myMute, ok := result["my_mute"].(map[string]any)
	if !ok || myMute["is_muted"] != true {
		t.Fatalf("unexpected my_mute payload: %+v", result["my_mute"])
	}
}

func TestAppChatMessagesListUsesQueryParams(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}
		if got := r.URL.Query().Get("limit"); got != "50" {
			t.Fatalf("unexpected limit query: %s", got)
		}
		if got := r.URL.Query().Get("before_id"); got != "msg-9" {
			t.Fatalf("unexpected before_id query: %s", got)
		}

		_ = json.NewEncoder(w).Encode([]map[string]any{
			{
				"id":              "msg-10",
				"room_id":         "room-2",
				"sender_id":       "u-2",
				"sender_username": "alice",
				"sender_nickname": "Alice",
				"content":         "你好",
				"message_type":    "text",
				"created_at":      "2026-03-24T01:00:00Z",
				"parts":           []map[string]any{},
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-messages-list",
		Method: "chat.messages.list",
		Params: mustJSONRaw(map[string]any{
			"room_id":   "room-2",
			"limit":     50,
			"before_id": "msg-9",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.messages.list to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.messages.list response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.messages.list envelope: %+v", envelope)
	}

	var messages []map[string]any
	if err := json.Unmarshal(envelope.Data, &messages); err != nil {
		t.Fatalf("decode chat.messages.list data failed: %v", err)
	}
	if len(messages) != 1 || messages[0]["id"] != "msg-10" {
		t.Fatalf("unexpected chat.messages.list payload: %+v", messages)
	}
}

func TestAppChatSendPostsMessagePayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["content"] != "你好，desktop-el" {
			t.Fatalf("unexpected content payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"message": map[string]any{
				"id":              "msg-11",
				"room_id":         "room-2",
				"sender_id":       "u-1",
				"sender_username": "me",
				"sender_nickname": "我",
				"content":         "你好，desktop-el",
				"message_type":    "text",
				"status":          "sent",
				"created_at":      "2026-03-24T02:00:00Z",
				"parts":           []map[string]any{},
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-send",
		Method: "chat.send",
		Params: mustJSONRaw(map[string]any{
			"room_id": "room-2",
			"content": "你好，desktop-el",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.send to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.send response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.send envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.send data failed: %v", err)
	}
	messagePayload, ok := result["message"].(map[string]any)
	if !ok {
		t.Fatalf("expected wrapped message payload, got: %+v", result)
	}
	if messagePayload["id"] != "msg-11" {
		t.Fatalf("unexpected sent message payload: %+v", messagePayload)
	}
}

func TestAppChatSendPostsAttachmentPartsPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}

		parts, ok := payload["parts"].([]any)
		if !ok || len(parts) != 1 {
			t.Fatalf("unexpected parts payload: %+v", payload)
		}

		part, ok := parts[0].(map[string]any)
		if !ok {
			t.Fatalf("unexpected part item: %+v", parts[0])
		}
		if part["type"] != "file" || part["key"] != "messages/room-2/files_demo.pdf" {
			t.Fatalf("unexpected attachment part payload: %+v", part)
		}
		if part["name"] != "demo.pdf" || part["mime"] != "application/pdf" {
			t.Fatalf("unexpected attachment metadata payload: %+v", part)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"message": map[string]any{
				"id":              "msg-attachment-1",
				"room_id":         "room-2",
				"sender_id":       "u-1",
				"sender_username": "me",
				"sender_nickname": "我",
				"content":         "[附件]",
				"message_type":    "file",
				"status":          "sent",
				"created_at":      "2026-03-24T03:00:00Z",
				"parts": []map[string]any{
					{
						"position":  0,
						"part_type": "file",
						"attachment": map[string]any{
							"key":  "messages/room-2/files_demo.pdf",
							"name": "demo.pdf",
							"mime": "application/pdf",
							"size": 1024,
						},
					},
				},
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-send-attachment",
		Method: "chat.send",
		Params: mustJSONRaw(map[string]any{
			"room_id": "room-2",
			"parts": []map[string]any{
				{
					"type": "file",
					"key":  "messages/room-2/files_demo.pdf",
					"name": "demo.pdf",
					"mime": "application/pdf",
					"size": 1024,
				},
			},
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.send with attachment parts to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.send attachment response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.send attachment envelope: %+v", envelope)
	}
}

func TestAppChatReadUntilPostsMessageID(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/read_until" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["message_id"] != "msg-11" {
			t.Fatalf("unexpected message_id payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "已标记 3 条消息为已读",
			"count":   3,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-read-until",
		Method: "chat.read_until",
		Params: mustJSONRaw(map[string]any{
			"room_id":    "room-2",
			"message_id": "msg-11",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.read_until to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.read_until response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.read_until envelope: %+v", envelope)
	}
	if envelope.Message != "已标记 3 条消息为已读" {
		t.Fatalf("unexpected chat.read_until message: %+v", envelope)
	}
}

func TestAppChatDeleteDeletesMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/msg-11" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodDelete {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":              "msg-11",
			"room_id":         "room-2",
			"sender_id":       "u-1",
			"sender_username": "me",
			"sender_nickname": "我",
			"content":         "已删除消息",
			"message_type":    "text",
			"created_at":      "2026-03-24T02:00:00Z",
			"is_deleted":      true,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-delete",
		Method: "chat.delete",
		Params: mustJSONRaw(map[string]any{
			"room_id":    "room-2",
			"message_id": "msg-11",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.delete to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.delete response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.delete envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.delete data failed: %v", err)
	}
	if result["id"] != "msg-11" || result["is_deleted"] != true {
		t.Fatalf("unexpected chat.delete payload: %+v", result)
	}
}

func TestAppChatAttachmentDownloadURLReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/attachments/download" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer access-token" {
			t.Fatalf("unexpected authorization header: %s", got)
		}
		if got := r.URL.Query().Get("key"); got != "messages/room-2/demo.pdf" {
			t.Fatalf("unexpected key query: %s", got)
		}
		if got := r.URL.Query().Get("expires_in_seconds"); got != "900" {
			t.Fatalf("unexpected expires_in_seconds query: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success":      true,
			"message":      "生成附件下载链接成功",
			"download_url": "https://download.example.com/messages/room-2/demo.pdf?signature=abc",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-download-url",
		Method: "chat.attachment.download_url",
		Params: mustJSONRaw(map[string]any{
			"room_id":            "room-2",
			"key":                "messages/room-2/demo.pdf",
			"expires_in_seconds": 900,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.download_url to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.attachment.download_url response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.attachment.download_url envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.attachment.download_url data failed: %v", err)
	}
	if result["download_url"] != "https://download.example.com/messages/room-2/demo.pdf?signature=abc" {
		t.Fatalf("unexpected chat.attachment.download_url payload: %+v", result)
	}
}

func TestAppChatAttachmentSignatureReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/attachments/signature" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["part_type"] != "file" || payload["filename"] != "demo.pdf" {
			t.Fatalf("unexpected attachment signature payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "生成消息附件直传签名成功",
			"key":     "messages/room-2/files_demo.pdf",
			"signature": map[string]any{
				"url":    "https://upload.example.com/direct",
				"method": "PUT",
				"headers": map[string]any{
					"Content-Type": "application/pdf",
				},
				"key": "messages/room-2/files_demo.pdf",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-signature",
		Method: "chat.attachment.signature",
		Params: mustJSONRaw(map[string]any{
			"room_id":      "room-2",
			"part_type":    "file",
			"filename":     "demo.pdf",
			"content_type": "application/pdf",
			"file_size":    1024,
			"hash_value":   "abc123",
			"hash_alg":     2,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.signature to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.attachment.signature response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.attachment.signature envelope: %+v", envelope)
	}

	var result map[string]any
	if err := json.Unmarshal(envelope.Data, &result); err != nil {
		t.Fatalf("decode chat.attachment.signature data failed: %v", err)
	}
	if result["key"] != "messages/room-2/files_demo.pdf" {
		t.Fatalf("unexpected chat.attachment.signature payload: %+v", result)
	}
}

func TestAppChatAttachmentMultipartInitiateReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/attachments/multipart/initiate" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["part_type"] != "video" || payload["file_size"] != float64(8*1024*1024) {
			t.Fatalf("unexpected multipart initiate payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success":     true,
			"message":     "初始化分片上传会话成功",
			"key":         "messages/room-2/videos_demo.mp4",
			"session_id":  "session-1",
			"part_size":   1048576,
			"total_parts": 8,
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-multipart-initiate",
		Method: "chat.attachment.multipart.initiate",
		Params: mustJSONRaw(map[string]any{
			"room_id":      "room-2",
			"part_type":    "video",
			"filename":     "demo.mp4",
			"content_type": "video/mp4",
			"file_size":    8 * 1024 * 1024,
			"hash_value":   "def456",
			"hash_alg":     2,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.multipart.initiate to succeed, got: %+v", response.Error)
	}

	var envelope httpclient.Response
	if err := json.Unmarshal(response.Result, &envelope); err != nil {
		t.Fatalf("decode chat.attachment.multipart.initiate response failed: %v", err)
	}
	if !envelope.Success || envelope.Code != 200 {
		t.Fatalf("unexpected chat.attachment.multipart.initiate envelope: %+v", envelope)
	}
}

func TestAppChatAttachmentMultipartPartSignatureReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/uploads/multipart/sessions/session-1/parts/signature" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["part_number"] != float64(2) {
			t.Fatalf("unexpected multipart part signature payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "ok",
			"signature": map[string]any{
				"url":    "https://upload.example.com/multipart/2",
				"method": "PUT",
				"headers": map[string]any{
					"Content-Type": "video/mp4",
				},
				"key": "messages/room-2/videos_demo.mp4",
			},
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-multipart-part-signature",
		Method: "chat.attachment.multipart.part_signature",
		Params: mustJSONRaw(map[string]any{
			"session_id":  "session-1",
			"part_number": 2,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.multipart.part_signature to succeed, got: %+v", response.Error)
	}
}

func TestAppChatAttachmentMultipartPartCommitReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/uploads/multipart/sessions/session-1/parts/commit" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["part_number"] != float64(2) || payload["etag"] != "etag-2" {
			t.Fatalf("unexpected multipart part commit payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "ok",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-multipart-part-commit",
		Method: "chat.attachment.multipart.part_commit",
		Params: mustJSONRaw(map[string]any{
			"session_id":  "session-1",
			"part_number": 2,
			"etag":        "etag-2",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.multipart.part_commit to succeed, got: %+v", response.Error)
	}
}

func TestAppChatAttachmentMultipartCompleteReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/uploads/multipart/sessions/session-1/complete" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		parts, ok := payload["parts"].([]any)
		if !ok || len(parts) != 2 {
			t.Fatalf("unexpected multipart complete payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "完成分片上传成功",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-multipart-complete",
		Method: "chat.attachment.multipart.complete",
		Params: mustJSONRaw(map[string]any{
			"session_id": "session-1",
			"parts": []map[string]any{
				{"part_number": 1, "etag": "etag-1"},
				{"part_number": 2, "etag": "etag-2"},
			},
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.multipart.complete to succeed, got: %+v", response.Error)
	}
}

func TestAppChatAttachmentUploadCommitReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-2/messages/attachments/commit" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request payload failed: %v", err)
		}
		if payload["key"] != "messages/room-2/files_demo.pdf" {
			t.Fatalf("unexpected attachment upload commit payload: %+v", payload)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "附件上传完成已登记",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-upload-commit",
		Method: "chat.attachment.upload.commit",
		Params: mustJSONRaw(map[string]any{
			"room_id":    "room-2",
			"key":        "messages/room-2/files_demo.pdf",
			"file_size":  1024,
			"hash_value": "abc123",
			"hash_alg":   2,
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.upload.commit to succeed, got: %+v", response.Error)
	}
}

func TestAppChatAttachmentMultipartAbortReturnsEnvelope(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/uploads/multipart/sessions/session-1/abort" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"message": "已中止分片上传",
		})
	}))
	defer server.Close()

	application := newTestApp(server.URL)
	application.session.Set("access-token", "refresh-token")
	application.httpClient.SetToken("access-token")

	rpcServer := application.RegisterRPC()
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-chat-attachment-multipart-abort",
		Method: "chat.attachment.multipart.abort",
		Params: mustJSONRaw(map[string]any{
			"session_id": "session-1",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected chat.attachment.multipart.abort to succeed, got: %+v", response.Error)
	}
}

func TestAppWSConnectEmitsPushEvent(t *testing.T) {
	var stdout bytes.Buffer

	upgrader := websocket.Upgrader{}
	done := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.URL.Query().Get("token"); got != "access-token" {
			t.Fatalf("unexpected token query: %s", got)
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("upgrade failed: %v", err)
		}
		defer conn.Close()

		if err := conn.WriteJSON(map[string]any{
			"type":       "message",
			"room_id":    "room-2",
			"message_id": "msg-12",
			"content":    "来自 websocket 的消息",
		}); err != nil {
			t.Fatalf("write websocket payload failed: %v", err)
		}

		<-done
	}))
	defer func() {
		close(done)
		server.Close()
	}()

	application := newTestApp("http://127.0.0.1:8010")
	application.encoder = rpc.NewEncoder(&stdout)

	rpcServer := application.RegisterRPC()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	response := rpcServer.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-ws-connect",
		Method: "ws.connect",
		Params: mustJSONRaw(map[string]any{
			"url":   wsURL,
			"token": "access-token",
		}),
	})
	if response.Error != nil {
		t.Fatalf("expected ws.connect to succeed, got: %+v", response.Error)
	}
	defer func() {
		if err := application.wsClient.Disconnect(); err != nil {
			t.Fatalf("disconnect websocket failed: %v", err)
		}
	}()

	event := waitForEmittedEvent(t, &stdout, "ws.push")

	var payload map[string]any
	if err := json.Unmarshal(event.Data, &payload); err != nil {
		t.Fatalf("decode ws.push payload failed: %v", err)
	}
	if payload["type"] != "message" || payload["message_id"] != "msg-12" {
		t.Fatalf("unexpected ws.push payload: %+v", payload)
	}
}

func newTestApp(baseURL string) *App {
	return New(
		config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			APIBaseURL:  baseURL,
			WSURL:       "ws://127.0.0.1:8010/ws",
			AppVersion:  "0.1.0",
			BuildNumber: 1,
			Channel:     "stable",
			FeatureFlags: map[string]bool{
				"desktop_el":   true,
				"go_transport": true,
			},
		},
		eventbus.New(),
		bootstrap.New(config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			APIBaseURL:  baseURL,
			WSURL:       "ws://127.0.0.1:8010/ws",
			AppVersion:  "0.1.0",
			BuildNumber: 1,
			Channel:     "stable",
			FeatureFlags: map[string]bool{
				"desktop_el":   true,
				"go_transport": true,
			},
		}),
		rpc.NewEncoder(&bytes.Buffer{}),
	)
}

func waitForEmittedEvent(t *testing.T, stdout *bytes.Buffer, eventName string) rpc.Event {
	t.Helper()

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if event, ok := findEmittedEvent(stdout.Bytes(), eventName); ok {
			return event
		}
		time.Sleep(10 * time.Millisecond)
	}

	t.Fatalf("expected emitted event %q, got: %s", eventName, stdout.String())
	return rpc.Event{}
}

func findEmittedEvent(output []byte, eventName string) (rpc.Event, bool) {
	for _, line := range bytes.Split(output, []byte("\n")) {
		line = bytes.TrimSpace(line)
		if len(line) == 0 {
			continue
		}

		var event rpc.Event
		if err := json.Unmarshal(line, &event); err != nil {
			continue
		}
		if event.Type == rpc.TypeEvent && event.Event == eventName {
			return event, true
		}
	}

	return rpc.Event{}, false
}
