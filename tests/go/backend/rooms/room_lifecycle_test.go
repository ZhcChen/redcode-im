package rooms_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestRoomCreateJoinLeaveAndMembers_OK(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("rooma")
	userB := testutil.UniqueUsername("roomb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)

	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "room-test")

	membersBefore := listMembers(t, c, loginA.Token, room.ID)
	assertHasMember(t, membersBefore, loginA.User.ID)
	assertHasMember(t, membersBefore, loginB.User.ID)

	leaveReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/leave", loginB.Token, nil)
	leaveResp, err := c.HTTP.Do(leaveReq)
	if err != nil {
		t.Fatalf("leave room failed: %v", err)
	}
	defer leaveResp.Body.Close()
	if leaveResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(leaveResp.Body)
		t.Fatalf("leave room expect 200, got %d: %s", leaveResp.StatusCode, string(body))
	}

	joinReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/join", loginB.Token, nil)
	joinResp, err := c.HTTP.Do(joinReq)
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	defer joinResp.Body.Close()
	if joinResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(joinResp.Body)
		t.Fatalf("join room expect 200, got %d: %s", joinResp.StatusCode, string(body))
	}

	membersAfter := listMembers(t, c, loginA.Token, room.ID)
	assertHasMember(t, membersAfter, loginA.User.ID)
	assertHasMember(t, membersAfter, loginB.User.ID)
}

func TestRoomLifecycle_OutsiderReadUntilLocalizedError(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	owner := registerAndLogin(t, c, testutil.UniqueUsername("roomlc-owner"), password)
	member := registerAndLogin(t, c, testutil.UniqueUsername("roomlc-member"), password)
	outsider := registerAndLogin(t, c, testutil.UniqueUsername("roomlc-outsider"), password)
	room := testutil.CreateGroupRoom(t, c, owner.Token, member.User.ID, "room-lifecycle-i18n")

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/read_until",
		outsider.Token,
		map[string]any{
			"message_id": "00000000-0000-0000-0000-000000000001",
		},
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("outsider read_until request failed: %v", err)
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

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func listMembers(t *testing.T, c *testutil.Client, token string, roomID string) []struct {
	UserID string `json:"user_id"`
} {
	t.Helper()
	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/rooms/"+roomID+"/members", token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("list members failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("list members expect 200, got %d: %s", resp.StatusCode, string(body))
	}
	var result []struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode list members failed: %v", err)
	}
	return result
}

func assertHasMember(t *testing.T, members []struct {
	UserID string `json:"user_id"`
}, userID string) {
	t.Helper()
	for _, m := range members {
		if m.UserID == userID {
			return
		}
	}
	t.Fatalf("member not found: %s, members=%+v", userID, members)
}
