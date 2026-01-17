package admin_test

import (
	"os"
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type adminUsersListResponse struct {
	Users []struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Status   string `json:"status"`
	} `json:"users"`
	Total    int `json:"total"`
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
}

type adminUserInfo struct {
	ID       string  `json:"id"`
	Username string  `json:"username"`
	Email    string  `json:"email"`
	Nickname *string `json:"nickname"`
	Status   string  `json:"status"`
}

type adminOperationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdmin_AdminUsers_ListCreateAndLock(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin users management test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respList, bodyList, err := c.DoJSON("GET", "/api/admin/admin-users?page=1&page_size=20", nil, admin.Token)
	if err != nil {
		t.Fatalf("list admin users http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list admin users status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list adminUsersListResponse
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode admin users list: %v body=%s", err, string(bodyList))
	}
	if list.Page <= 0 || list.PageSize <= 0 || list.Total < 0 {
		t.Fatalf("unexpected pagination: %+v body=%s", list, string(bodyList))
	}

	// 默认管理员应存在
	if len(list.Users) == 0 || !slices.ContainsFunc(list.Users, func(u struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Status   string `json:"status"`
	}) bool { return u.Username == adminUser }) {
		t.Fatalf("expected default admin in list, got %+v", list.Users)
	}

	newAdminUser := "go_admin_" + time.Now().Format("150405.000000000")
	newAdminPass := "Passw0rd!"

	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/admin-users", map[string]any{
		"username": newAdminUser,
		"email":    newAdminUser + "@example.com",
		"password": newAdminPass,
		"nickname": "go-admin",
	}, admin.Token)
	if err != nil {
		t.Fatalf("create admin user http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create admin user status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created adminUserInfo
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode created admin user: %v body=%s", err, string(bodyCreate))
	}
	if created.ID == "" || created.Username != newAdminUser || created.Email == "" {
		t.Fatalf("unexpected created admin user: %+v body=%s", created, string(bodyCreate))
	}

	// 锁定该管理员
	respLock, bodyLock, err := c.DoJSON("PATCH", "/api/admin/admin-users/"+created.ID+"/status", map[string]any{
		"status": "locked",
	}, admin.Token)
	if err != nil {
		t.Fatalf("lock admin user http error: %v", err)
	}
	if respLock.StatusCode != 200 {
		t.Fatalf("lock admin user status=%d body=%s", respLock.StatusCode, string(bodyLock))
	}
	var op adminOperationResponse
	if err := testutil.DecodeJSON(bodyLock, &op); err != nil {
		t.Fatalf("decode lock admin user: %v body=%s", err, string(bodyLock))
	}
	if !op.Success {
		t.Fatalf("expected lock success=true, body=%s", string(bodyLock))
	}

	// 被锁定账号应无法登录（403）
	respLogin, bodyLogin, err := c.DoJSON("POST", "/auth/admin/login", map[string]any{
		"username": newAdminUser,
		"password": newAdminPass,
	}, "")
	if err != nil {
		t.Fatalf("admin login (locked) http error: %v", err)
	}
	if respLogin.StatusCode != 403 {
		t.Fatalf("expected admin login (locked)=403, got %d body=%s", respLogin.StatusCode, string(bodyLogin))
	}
}
