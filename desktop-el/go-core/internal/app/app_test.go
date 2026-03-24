package app

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/auth"
	"desktop-el-core/internal/bootstrap"
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/eventbus"
	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/rpc"
	"desktop-el-core/internal/state"
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
			"id":        "u-2",
			"username":  "13800138000",
			"email":     "13800138000@example.com",
			"nickname":  "测试用户",
			"avatar_url": nil,
			"status":    "active",
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
				"id":        "u-1",
				"username":  "13800000000",
				"email":     "demo@example.com",
				"nickname":  "新的昵称",
				"avatar_url": nil,
				"status":    "active",
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
			"status":      "accepted",
			"message":     "hi",
			"created_at":  "2026-03-24T00:00:00Z",
			"responded_at": "2026-03-24T00:05:00Z",
			"is_incoming": true,
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
				"desktop_el": true,
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
				"desktop_el": true,
				"go_transport": true,
			},
		}),
		rpc.NewEncoder(&bytes.Buffer{}),
	)
}
