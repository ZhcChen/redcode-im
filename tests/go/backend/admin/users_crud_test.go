package admin_test

import (
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type userOperationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type userDetailResponse struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	Email    string  `json:"email"`
	Nickname *string `json:"nickname"`
}

func TestAdmin_Users_CreateDetailUpdateDelete(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin users crud test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	username := testutil.UniquePhone()
	password := "Passw0rd!"
	email := username + "@example.com"

	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/users", map[string]any{
		"username": username,
		"email":    email,
		"password": password,
		"nickname": "go-admin-user",
	}, admin.Token)
	if err != nil {
		t.Fatalf("admin create user http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("admin create user status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created userOperationResponse
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode admin create user: %v body=%s", err, string(bodyCreate))
	}
	if !created.Success {
		t.Fatalf("expected create user success=true, body=%s", string(bodyCreate))
	}

	// 从用户侧登录获取 user_id
	login := testutil.Login(t, c, username, password)
	if login.User.ID == "" {
		t.Fatalf("expected login user id non-empty: %+v", login.User)
	}

	userID := login.User.ID

	respDetail, bodyDetail, err := c.DoJSON("GET", "/api/admin/users/"+userID, nil, admin.Token)
	if err != nil {
		t.Fatalf("get user detail http error: %v", err)
	}
	if respDetail.StatusCode != 200 {
		t.Fatalf("get user detail status=%d body=%s", respDetail.StatusCode, string(bodyDetail))
	}
	var detail userDetailResponse
	if err := testutil.DecodeJSON(bodyDetail, &detail); err != nil {
		t.Fatalf("decode user detail: %v body=%s", err, string(bodyDetail))
	}
	if detail.ID != userID || detail.Username != username {
		t.Fatalf("unexpected user detail: %+v body=%s", detail, string(bodyDetail))
	}
	if detail.Email == "" {
		t.Fatalf("expected email non-empty: %+v body=%s", detail, string(bodyDetail))
	}

	newNick := "go-upd-" + time.Now().Format("150405.000000000")
	respUpd, bodyUpd, err := c.DoJSON("PATCH", "/api/admin/users/"+userID, map[string]any{
		"nickname": newNick,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user http error: %v", err)
	}
	if respUpd.StatusCode != 200 {
		t.Fatalf("update user status=%d body=%s", respUpd.StatusCode, string(bodyUpd))
	}
	var upd userOperationResponse
	if err := testutil.DecodeJSON(bodyUpd, &upd); err != nil {
		t.Fatalf("decode update user: %v body=%s", err, string(bodyUpd))
	}
	if !upd.Success {
		t.Fatalf("expected update user success=true, body=%s", string(bodyUpd))
	}

	respDetail2, bodyDetail2, err := c.DoJSON("GET", "/api/admin/users/"+userID, nil, admin.Token)
	if err != nil {
		t.Fatalf("get user detail (after) http error: %v", err)
	}
	if respDetail2.StatusCode != 200 {
		t.Fatalf("get user detail (after) status=%d body=%s", respDetail2.StatusCode, string(bodyDetail2))
	}
	var detail2 userDetailResponse
	if err := testutil.DecodeJSON(bodyDetail2, &detail2); err != nil {
		t.Fatalf("decode user detail (after): %v body=%s", err, string(bodyDetail2))
	}
	if detail2.Nickname == nil || strings.TrimSpace(*detail2.Nickname) != newNick {
		t.Fatalf("expected nickname updated to %q, got %+v body=%s", newNick, detail2.Nickname, string(bodyDetail2))
	}

	// update with empty payload should be success=false (契约：200 + success=false)
	respNoop, bodyNoop, err := c.DoJSON("PATCH", "/api/admin/users/"+userID, map[string]any{}, admin.Token)
	if err != nil {
		t.Fatalf("update user (noop) http error: %v", err)
	}
	if respNoop.StatusCode != 200 {
		t.Fatalf("update user (noop) status=%d body=%s", respNoop.StatusCode, string(bodyNoop))
	}
	var noop userOperationResponse
	if err := testutil.DecodeJSON(bodyNoop, &noop); err != nil {
		t.Fatalf("decode update user (noop): %v body=%s", err, string(bodyNoop))
	}
	if noop.Success {
		t.Fatalf("expected update user (noop) success=false, body=%s", string(bodyNoop))
	}

	respDel, bodyDel, err := c.DoJSON("DELETE", "/api/admin/users/"+userID, nil, admin.Token)
	if err != nil {
		t.Fatalf("delete user http error: %v", err)
	}
	if respDel.StatusCode != 200 {
		t.Fatalf("delete user status=%d body=%s", respDel.StatusCode, string(bodyDel))
	}
	var del userOperationResponse
	if err := testutil.DecodeJSON(bodyDel, &del); err != nil {
		t.Fatalf("decode delete user: %v body=%s", err, string(bodyDel))
	}
	if !del.Success {
		t.Fatalf("expected delete user success=true, body=%s", string(bodyDel))
	}

	respDetail3, _, err := c.DoJSON("GET", "/api/admin/users/"+userID, nil, admin.Token)
	if err != nil {
		t.Fatalf("get user detail (deleted) http error: %v", err)
	}
	if respDetail3.StatusCode != 404 {
		t.Fatalf("expected deleted user detail=404, got %d", respDetail3.StatusCode)
	}
}

