package system_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type localeAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestLocaleContract_AcceptLanguageEnglish(t *testing.T) {
	c := testutil.NewClient()

	req, err := http.NewRequest(
		http.MethodGet,
		c.BaseURL+"/versions/latest/download-url?platform=bad&channel=locale-contract",
		nil,
	)
	if err != nil {
		t.Fatalf("build locale contract request failed: %v", err)
	}
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("execute locale contract request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocaleError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"version.platform_unsupported",
		"Unsupported platform: bad. Supported platforms: windows, macos, ios, android, linux.",
		map[string]string{
			"platform":            "bad",
			"supported_platforms": "windows, macos, ios, android, linux",
		},
	)
}

func TestLocaleContract_UnsupportedLocaleFallsBackToZhCN(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	owner := registerAndLoginLocaleContract(t, c, testutil.UniqueUsername("locale-owner"), password)
	member := registerAndLoginLocaleContract(t, c, testutil.UniqueUsername("locale-member"), password)
	outsider := registerAndLoginLocaleContract(t, c, testutil.UniqueUsername("locale-outsider"), password)
	room := testutil.CreateGroupRoom(t, c, owner.Token, member.User.ID, "locale-contract-room")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/read_until",
		outsider.Token,
		map[string]any{
			"message_id": "00000000-0000-0000-0000-000000000001",
		},
	)
	req.Header.Set("Accept-Language", "fr-FR")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("execute locale fallback request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocaleError(
		t,
		resp,
		http.StatusForbidden,
		40301,
		"room.membership_required",
		"您不是当前房间成员",
		nil,
	)
}

func registerAndLoginLocaleContract(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func assertLocaleError(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
	wantCode int,
	wantKey string,
	wantMessage string,
	wantParams map[string]string,
) {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload localeAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode locale error response failed: %v", err)
	}

	if payload.Code != wantCode {
		t.Fatalf("unexpected code: want %d got %d", wantCode, payload.Code)
	}
	if payload.MessageKey != wantKey {
		t.Fatalf("unexpected message_key: want %s got %s", wantKey, payload.MessageKey)
	}
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: want %s got %s", wantMessage, payload.Message)
	}
	if wantParams == nil {
		if payload.MessageParams != nil {
			t.Fatalf("expected nil message_params, got %+v", payload.MessageParams)
		}
	} else {
		if payload.MessageParams == nil {
			t.Fatalf("expected message_params, got nil")
		}
		for key, value := range wantParams {
			if payload.MessageParams[key] != value {
				t.Fatalf("unexpected message_params[%s]: want %s got %s", key, value, payload.MessageParams[key])
			}
		}
	}
	if payload.Details != nil {
		t.Fatalf("expected nil details, got %q", *payload.Details)
	}
}
