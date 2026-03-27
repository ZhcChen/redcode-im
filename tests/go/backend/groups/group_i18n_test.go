package groups_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type groupAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestGroupAddMembersInvalidUserID_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("group-owner")
	userB := testutil.UniqueUsername("group-member")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "group-i18n-room")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/members",
		loginA.Token,
		map[string]any{
			"user_ids": []string{"not-a-uuid"},
		},
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("add group members request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedGroupError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"group.member_id_invalid",
		"User ID is invalid: not-a-uuid.",
		map[string]string{
			"user_id": "not-a-uuid",
		},
	)
}

func TestGroupRemoveOwnerForbidden_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("group-owner")
	userB := testutil.UniqueUsername("group-member")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "group-remove-owner-room")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodDelete,
		c.BaseURL+"/rooms/"+room.ID+"/members/"+loginA.User.ID,
		loginA.Token,
		nil,
	)
	req.Header.Set("Accept-Language", "zh-CN")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("remove group owner request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedGroupError(
		t,
		resp,
		http.StatusForbidden,
		40301,
		"group.owner_cannot_be_removed",
		"无法移除群主",
		nil,
	)
}

func TestGroupDetailNotFound_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("group-detail")
	loginA := registerAndLogin(t, c, userA, password)

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodGet,
		c.BaseURL+"/rooms/550e8400-e29b-41d4-a716-446655440000/detail",
		loginA.Token,
		nil,
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("group detail request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedGroupError(
		t,
		resp,
		http.StatusNotFound,
		40401,
		"group.not_found",
		"Group not found.",
		nil,
	)
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func assertLocalizedGroupError(
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

	var payload groupAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized group error response failed: %v", err)
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
