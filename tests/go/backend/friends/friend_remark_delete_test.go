package friends_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type updateRemarkResp struct {
	Remark *string `json:"remark"`
}

type deleteFriendResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type friendInfoWithRemark struct {
	ID           string  `json:"id"`
	FriendRemark *string `json:"friend_remark"`
	User         struct {
		ID       string `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
}

func updateFriendRemark(t *testing.T, c *testutil.Client, token, friendUserID string, remark *string) updateRemarkResp {
	t.Helper()
	payload := map[string]any{
		"remark": remark,
	}
	resp, body, err := c.DoJSON("PATCH", "/friends/"+friendUserID+"/remark", payload, token)
	if err != nil {
		t.Fatalf("update remark http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("update remark status=%d body=%s", resp.StatusCode, string(body))
	}
	var out updateRemarkResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("update remark decode: %v body=%s", err, string(body))
	}
	return out
}

func listFriendsWithRemark(t *testing.T, c *testutil.Client, token string) []friendInfoWithRemark {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/friends", nil, token)
	if err != nil {
		t.Fatalf("list friends http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list friends status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []friendInfoWithRemark
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list friends decode: %v body=%s", err, string(body))
	}
	return items
}

func deleteFriend(t *testing.T, c *testutil.Client, token, friendUserID string) deleteFriendResp {
	t.Helper()
	resp, body, err := c.DoJSON("DELETE", "/friends/"+friendUserID, nil, token)
	if err != nil {
		t.Fatalf("delete friend http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("delete friend status=%d body=%s", resp.StatusCode, string(body))
	}
	var out deleteFriendResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("delete friend decode: %v body=%s", err, string(body))
	}
	if !out.Success {
		t.Fatalf("delete friend success=false body=%s", string(body))
	}
	return out
}

func TestFriends_RemarkAndDelete(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	loginA := testutil.Login(t, c, userA.Username, pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	req := createFriendRequest(t, c, loginA.Token, userB.ID)
	_ = respondFriendRequest(t, c, loginB.Token, req.ID, "accept")

	remark := "go-remark-" + time.Now().Format("150405.000000000")
	updated := updateFriendRemark(t, c, loginA.Token, userB.ID, &remark)
	if updated.Remark == nil || *updated.Remark != remark {
		t.Fatalf("expected remark=%q, got %+v", remark, updated)
	}

	friendsA := listFriendsWithRemark(t, c, loginA.Token)
	if !slices.ContainsFunc(friendsA, func(f friendInfoWithRemark) bool {
		return f.User.ID == userB.ID && f.FriendRemark != nil && *f.FriendRemark == remark
	}) {
		t.Fatalf("expected friendsA contain userB with friend_remark=%q, got %+v", remark, friendsA)
	}

	deleteFriend(t, c, loginA.Token, userB.ID)

	friendsA2 := listFriends(t, c, loginA.Token)
	if slices.ContainsFunc(friendsA2, func(f friendInfo) bool { return f.User.ID == userB.ID }) {
		t.Fatalf("expected userB removed from friendsA after delete, got %+v", friendsA2)
	}
	friendsB2 := listFriends(t, c, loginB.Token)
	if slices.ContainsFunc(friendsB2, func(f friendInfo) bool { return f.User.ID == userA.ID }) {
		t.Fatalf("expected userA removed from friendsB after delete, got %+v", friendsB2)
	}
}

func TestFriends_RequestDecline_DoesNotCreateFriendship(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	loginA := testutil.Login(t, c, userA.Username, pass)
	loginB := testutil.Login(t, c, userB.Username, pass)

	req := createFriendRequest(t, c, loginA.Token, userB.ID)
	declined := respondFriendRequest(t, c, loginB.Token, req.ID, "decline")
	if declined.Status != "declined" {
		t.Fatalf("expected status=declined, got %q", declined.Status)
	}

	friendsA := listFriends(t, c, loginA.Token)
	if slices.ContainsFunc(friendsA, func(f friendInfo) bool { return f.User.ID == userB.ID }) {
		t.Fatalf("expected no friendship after decline, got friendsA=%+v", friendsA)
	}
	friendsB := listFriends(t, c, loginB.Token)
	if slices.ContainsFunc(friendsB, func(f friendInfo) bool { return f.User.ID == userA.ID }) {
		t.Fatalf("expected no friendship after decline, got friendsB=%+v", friendsB)
	}
}
