package rooms_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type roomAPIErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

func TestCreateRoomInvalidMemberID_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	owner := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-owner"), password)

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms",
		owner.Token,
		map[string]any{
			"name":       "room-i18n-create",
			"room_type":  "group",
			"member_ids": []string{"not-a-uuid"},
		},
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create room request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedRoomError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"room.member_id_invalid",
		"Member ID is invalid: not-a-uuid.",
		map[string]string{
			"user_id": "not-a-uuid",
		},
	)
}

func TestGetRoomMembershipRequired_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	owner := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-owner"), password)
	member := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-member"), password)
	outsider := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-outsider"), password)
	room := testutil.CreateGroupRoom(t, c, owner.Token, member.User.ID, "room-i18n-membership")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodGet,
		c.BaseURL+"/rooms/"+room.ID,
		outsider.Token,
		nil,
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("get room request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedRoomError(
		t,
		resp,
		http.StatusForbidden,
		40301,
		"room.membership_required",
		"You are not a member of this room.",
		nil,
	)
}

func TestTransferRoomOwnerSameOwner_Localized(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	owner := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-owner"), password)
	member := registerAndLoginRoomI18n(t, c, testutil.UniqueUsername("room-member"), password)
	room := testutil.CreateGroupRoom(t, c, owner.Token, member.User.ID, "room-i18n-transfer")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/transfer",
		owner.Token,
		map[string]any{
			"new_owner_id": owner.User.ID,
		},
	)
	req.Header.Set("Accept-Language", "zh-CN")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("transfer room owner request failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedRoomError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"room.new_owner_same_as_current",
		"新群主必须与当前群主不同",
		nil,
	)
}

func registerAndLoginRoomI18n(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func assertLocalizedRoomError(
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

	var payload roomAPIErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized room error response failed: %v", err)
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
