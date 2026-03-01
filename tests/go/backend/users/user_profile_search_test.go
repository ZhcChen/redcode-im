package users_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestUserSearchAndUpdateMe_OK(t *testing.T) {
	c := testutil.NewClient()

	userA := testutil.UniqueUsername("usera")
	userB := testutil.UniqueUsername("userb")
	password := "pass123456"

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)

	keyword := userB[len(userB)-6:]
	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/users/search?keyword="+keyword, loginA.Token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("search users failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("search users expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var users []struct {
		ID       string  `json:"id"`
		Username string  `json:"username"`
		Nickname *string `json:"nickname"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		t.Fatalf("decode search response failed: %v", err)
	}
	found := false
	for _, u := range users {
		if u.ID == loginB.User.ID {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expect userB in search result, userB=%s result=%+v", loginB.User.ID, users)
	}

	newNickname := "Alpha Tester"
	patchReq := testutil.NewAuthedJSONRequest(t, http.MethodPatch, c.BaseURL+"/users/me", loginA.Token, map[string]any{
		"nickname": newNickname,
	})
	patchResp, err := c.HTTP.Do(patchReq)
	if err != nil {
		t.Fatalf("patch /users/me failed: %v", err)
	}
	defer patchResp.Body.Close()
	if patchResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(patchResp.Body)
		t.Fatalf("patch /users/me expect 200, got %d: %s", patchResp.StatusCode, string(body))
	}

	var me struct {
		ID       string  `json:"id"`
		Username string  `json:"username"`
		Nickname *string `json:"nickname"`
	}
	if err := json.NewDecoder(patchResp.Body).Decode(&me); err != nil {
		t.Fatalf("decode patch response failed: %v", err)
	}
	if me.Nickname == nil || strings.TrimSpace(*me.Nickname) != newNickname {
		t.Fatalf("nickname not updated, got=%v", me.Nickname)
	}

	getReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/users/"+loginA.User.ID, loginA.Token, nil)
	getResp, err := c.HTTP.Do(getReq)
	if err != nil {
		t.Fatalf("get /users/{id} failed: %v", err)
	}
	defer getResp.Body.Close()
	if getResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(getResp.Body)
		t.Fatalf("get /users/{id} expect 200, got %d: %s", getResp.StatusCode, string(body))
	}
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}
