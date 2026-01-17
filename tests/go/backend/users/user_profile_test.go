package users_test

import (
	"net/url"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type userInfo struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	Email    string  `json:"email"`
	Nickname *string `json:"nickname"`
}

func searchUsers(t *testing.T, c *testutil.Client, token, keyword string, limit int) []userInfo {
	t.Helper()
	path := "/users/search"
	q := url.Values{}
	q.Set("keyword", keyword)
	if limit > 0 {
		q.Set("limit", "10")
	}
	path += "?" + q.Encode()

	resp, body, err := c.DoJSON("GET", path, nil, token)
	if err != nil {
		t.Fatalf("search users http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("search users status=%d body=%s", resp.StatusCode, string(body))
	}
	var out []userInfo
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("search users decode: %v body=%s", err, string(body))
	}
	return out
}

func getUserByID(t *testing.T, c *testutil.Client, token, userID string) userInfo {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/users/"+userID, nil, token)
	if err != nil {
		t.Fatalf("get user http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get user status=%d body=%s", resp.StatusCode, string(body))
	}
	var out userInfo
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("get user decode: %v body=%s", err, string(body))
	}
	if out.ID == "" || out.Username == "" {
		t.Fatalf("get user missing fields: body=%s", string(body))
	}
	return out
}

func TestUsers_SearchAndGetByID(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	userA := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	userB := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	loginA := testutil.Login(t, c, userA.Username, pass)

	// keyword 为空：400
	resp, body, err := c.DoJSON("GET", "/users/search?keyword=", nil, loginA.Token)
	if err != nil {
		t.Fatalf("search users (empty) http error: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("expected empty keyword status=400, got %d body=%s", resp.StatusCode, string(body))
	}

	// 搜索 userB，应能返回 userB，且不应包含自己（通常实现会排除 current_user）
	items := searchUsers(t, c, loginA.Token, userB.Username, 10)
	foundB := false
	foundA := false
	for _, u := range items {
		if u.ID == userB.ID {
			foundB = true
		}
		if u.ID == userA.ID {
			foundA = true
		}
	}
	if !foundB {
		t.Fatalf("expected search results contain userB=%s, got %v", userB.ID, items)
	}
	if foundA {
		t.Fatalf("expected search results exclude current userA=%s, got %v", userA.ID, items)
	}

	got := getUserByID(t, c, loginA.Token, userB.ID)
	if got.ID != userB.ID || got.Username != userB.Username {
		t.Fatalf("unexpected get user result: %+v want id=%s username=%s", got, userB.ID, userB.Username)
	}

	// 非法 user_id：400
	resp2, body2, err := c.DoJSON("GET", "/users/not-a-uuid", nil, loginA.Token)
	if err != nil {
		t.Fatalf("get user (invalid uuid) http error: %v", err)
	}
	if resp2.StatusCode != 400 {
		t.Fatalf("expected invalid uuid status=400, got %d body=%s", resp2.StatusCode, string(body2))
	}
}

func TestUsers_UpdateMePasswordAndDeactivate(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"
	newPass := "NewPassw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	// 更新昵称（基础 profile 更新回归）
	newNick := "go-nick-" + time.Now().Format("150405.000000000")
	resp, body, err := c.DoJSON("PATCH", "/users/me", map[string]any{"nickname": newNick}, login.Token)
	if err != nil {
		t.Fatalf("update me http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("update me status=%d body=%s", resp.StatusCode, string(body))
	}
	var updated userInfo
	if err := testutil.DecodeJSON(body, &updated); err != nil {
		t.Fatalf("update me decode: %v body=%s", err, string(body))
	}
	if updated.Nickname == nil || strings.TrimSpace(*updated.Nickname) != newNick {
		t.Fatalf("expected nickname=%q, got %+v body=%s", newNick, updated, string(body))
	}

	// 修改密码
	resp2, body2, err := c.DoJSON("POST", "/users/me/password", map[string]any{
		"old_password": pass,
		"new_password": newPass,
	}, login.Token)
	if err != nil {
		t.Fatalf("change password http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("change password status=%d body=%s", resp2.StatusCode, string(body2))
	}

	// 新密码应可登录
	login2 := testutil.Login(t, c, user.Username, newPass)
	if login2.Token == "" {
		t.Fatalf("expected login with new password succeed, got empty token")
	}

	// 注销/停用账号
	resp3, body3, err := c.DoJSON("DELETE", "/users/me", nil, login2.Token)
	if err != nil {
		t.Fatalf("deactivate me http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("deactivate me status=%d body=%s", resp3.StatusCode, string(body3))
	}

	// 再次登录应失败（InvalidCredentials -> 401）
	resp4, body4, err := c.DoJSON("POST", "/auth/login", map[string]any{
		"username": user.Username,
		"password": newPass,
	}, "")
	if err != nil {
		t.Fatalf("login after deactivate http error: %v", err)
	}
	if resp4.StatusCode != 401 {
		t.Fatalf("expected login after deactivate status=401, got %d body=%s", resp4.StatusCode, string(body4))
	}
}

