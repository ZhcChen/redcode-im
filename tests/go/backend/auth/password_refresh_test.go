package auth_test

import (
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestPasswordLoginAndRefresh_OK(t *testing.T) {
	c := testutil.NewClient()
	username := testutil.UniqueUsername("auth_user")
	password := "pass123456"

	registered := testutil.RegisterUser(t, c, username, password)
	loginResp := testutil.LoginWithPassword(t, c, username, password)

	if loginResp.User.ID != registered.ID {
		t.Fatalf("login user id mismatch: expect %s, got %s", registered.ID, loginResp.User.ID)
	}

	refreshResp := testutil.RefreshToken(t, c, loginResp.RefreshToken)
	if refreshResp.User.ID != registered.ID {
		t.Fatalf("refresh user id mismatch: expect %s, got %s", registered.ID, refreshResp.User.ID)
	}

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/auth/me", refreshResp.Token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request /auth/me failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect /auth/me 200, got %d", resp.StatusCode)
	}
}
