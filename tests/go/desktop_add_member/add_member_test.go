package desktop_add_member

import (
	"slices"
	"testing"
)

type roomResponse struct {
	Room struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"room"`
}

type memberInfo struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
}

type addMembersResp struct {
	Success       bool     `json:"success"`
	AddedUserIDs  []string `json:"added_user_ids"`
	SkippedUserIDs []string `json:"skipped_user_ids"`
}

// createGroup creates a group with at least one initial member.
func createGroup(t *testing.T, c *Client, token string, name string, memberIDs []string) string {
	t.Helper()
	payload := map[string]any{
		"name":        name,
		"description": "go-test",
		"member_ids":  memberIDs,
	}
	resp, body, err := c.DoJSON("POST", "/rooms", payload, token)
	if err != nil {
		t.Fatalf("create group http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("create group status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr roomResponse
	if err := Decode(body, &rr); err != nil {
		t.Fatalf("create group decode: %v body=%s", err, string(body))
	}
	return rr.Room.ID
}

func addMembers(t *testing.T, c *Client, token, roomID string, userIDs []string) addMembersResp {
	t.Helper()
	payload := map[string]any{
		"user_ids": userIDs,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members", payload, token)
	if err != nil {
		t.Fatalf("add members http error: %v", err)
	}
	var ar addMembersResp
	if err := Decode(body, &ar); err != nil {
		t.Fatalf("add members decode: %v body=%s", err, string(body))
	}
	if resp.StatusCode != 200 || !ar.Success {
		t.Fatalf("add members failed status=%d body=%s", resp.StatusCode, string(body))
	}
	return ar
}

func listMembers(t *testing.T, c *Client, token, roomID string) []memberInfo {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, token)
	if err != nil {
		t.Fatalf("list members http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list members status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []memberInfo
	if err := Decode(body, &items); err != nil {
		t.Fatalf("list members decode: %v body=%s", err, string(body))
	}
	return items
}

func TestAddMembers_Success(t *testing.T) {
	c := NewClient()

	// 创建三个用户：群主、初始成员、待添加成员
	ownerName := uniquePhone()
	memberName := uniquePhone()
	newName := uniquePhone()

	pass := "Passw0rd!"

	ownerInfo := registerUser(t, c, ownerName, pass)
	memberUser := registerUser(t, c, memberName, pass)
	newInfo := registerUser(t, c, newName, pass)

	ownerLogin := login(t, c, ownerInfo.Username, pass)
	roomID := createGroup(t, c, ownerLogin.Token, "go-add-member", []string{memberUser.ID})

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
	c := NewClient()

	owner := registerUser(t, c, uniquePhone(), "Passw0rd!")
	normal := registerUser(t, c, uniquePhone(), "Passw0rd!")
	target := registerUser(t, c, uniquePhone(), "Passw0rd!")

	ownerLogin := login(t, c, owner.Username, "Passw0rd!")
	normalLogin := login(t, c, normal.Username, "Passw0rd!")

	roomID := createGroup(t, c, ownerLogin.Token, "go-add-member-np", []string{normal.ID})

	// 普通成员尝试添加他人，预期 403
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members", map[string]any{"user_ids": []string{target.ID}}, normalLogin.Token)
	if err != nil {
		t.Fatalf("no-permission http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403, got %d body=%s", resp.StatusCode, string(body))
	}
}
