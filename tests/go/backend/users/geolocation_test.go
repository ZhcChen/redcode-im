package users_test

import (
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestUsers_GetGeolocation(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	resp, body, err := c.DoJSON("GET", "/users/"+user.ID+"/geolocation", nil, login.Token)
	if err != nil {
		t.Fatalf("get user geolocation http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get user geolocation status=%d body=%s", resp.StatusCode, string(body))
	}
	var out any
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode user geolocation: %v body=%s", err, string(body))
	}
}
