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

	userA := testutil.UniqueEmail("rooma")
	userB := testutil.UniqueEmail("roomb")

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
