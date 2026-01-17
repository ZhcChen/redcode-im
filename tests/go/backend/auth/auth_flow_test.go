package auth_test

import (
	"testing"

	"redcode-im-tests/internal/testutil"
)

type meResponse struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type refreshResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
}

func getMe(t *testing.T, c *testutil.Client, token string) meResponse {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/auth/me", nil, token)
	if err != nil {
		t.Fatalf("get /auth/me http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get /auth/me status=%d body=%s", resp.StatusCode, string(body))
	}
	var me meResponse
	if err := testutil.DecodeJSON(body, &me); err != nil {
		t.Fatalf("decode /auth/me: %v body=%s", err, string(body))
	}
	if me.ID == "" || me.Username == "" {
		t.Fatalf("invalid /auth/me response: %+v body=%s", me, string(body))
	}
	return me
}

func refreshToken(t *testing.T, c *testutil.Client, refreshToken string) refreshResponse {
	t.Helper()
	payload := map[string]any{
		"refresh_token": refreshToken,
	}
	resp, body, err := c.DoJSON("POST", "/auth/refresh", payload, "")
	if err != nil {
		t.Fatalf("post /auth/refresh http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("post /auth/refresh status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr refreshResponse
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("decode /auth/refresh: %v body=%s", err, string(body))
	}
	if rr.Token == "" || rr.RefreshToken == "" {
		t.Fatalf("invalid /auth/refresh response: %+v body=%s", rr, string(body))
	}
	return rr
}

func TestAuth_RegisterLoginMeAndRefreshFlow(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	if login.Token == "" || login.RefreshToken == "" {
		t.Fatalf("login missing token/refresh_token: %+v", login)
	}

	me := getMe(t, c, login.Token)
	if me.ID != user.ID {
		t.Fatalf("expected me.id=%s got %s", user.ID, me.ID)
	}

	refreshed := refreshToken(t, c, login.RefreshToken)
	me2 := getMe(t, c, refreshed.Token)
	if me2.ID != user.ID {
		t.Fatalf("expected me.id=%s got %s (after refresh)", user.ID, me2.ID)
	}
}

