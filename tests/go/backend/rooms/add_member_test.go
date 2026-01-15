package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type memberInfo struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
}

type addMembersResp struct {
	Success        bool     `json:"success"`
	AddedUserIDs   []string `json:"added_user_ids"`
	SkippedUserIDs []string `json:"skipped_user_ids"`
}

func addMembers(t *testing.T, c *testutil.Client, token, roomID string, userIDs []string) addMembersResp {
	t.Helper()
	payload := map[string]any{
		"user_ids": userIDs,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members", payload, token)
	if err != nil {
		t.Fatalf("add members http error: %v", err)
	}
	var ar addMembersResp
	if err := testutil.DecodeJSON(body, &ar); err != nil {
		t.Fatalf("add members decode: %v body=%s", err, string(body))
	}
	if resp.StatusCode != 200 || !ar.Success {
		t.Fatalf("add members failed status=%d body=%s", resp.StatusCode, string(body))
	}
	return ar
}

func listMembers(t *testing.T, c *testutil.Client, token, roomID string) []memberInfo {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, token)
	if err != nil {
		t.Fatalf("list members http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list members status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []memberInfo
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list members decode: %v body=%s", err, string(body))
	}
	return items
}

func TestAddMembers_Success(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	ownerInfo := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	memberUser := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	newInfo := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, ownerInfo.Username, pass)
	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-add-member-"+time.Now().Format("150405"), []string{memberUser.ID})

	addResp := addMembers(t, c, ownerLogin.Token, roomID, []string{newInfo.ID})
	if len(addResp.AddedUserIDs) != 1 || addResp.AddedUserIDs[0] != newInfo.ID {
		t.Fatalf("unexpected addResp: %+v", addResp)
	}

	members := listMembers(t, c, ownerLogin.Token, roomID)
	if !slices.ContainsFunc(members, func(m memberInfo) bool { return m.UserID == newInfo.ID }) {
		t.Fatalf("new member not in list, got %v", members)
	}
}

func TestAddMembers_NoPermission(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	normal := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	target := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	normalLogin := testutil.Login(t, c, normal.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-add-member-np-"+time.Now().Format("150405"), []string{normal.ID})

	// 普通成员尝试添加他人，预期 403
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members", map[string]any{"user_ids": []string{target.ID}}, normalLogin.Token)
	if err != nil {
		t.Fatalf("no-permission http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403, got %d body=%s", resp.StatusCode, string(body))
	}
}
