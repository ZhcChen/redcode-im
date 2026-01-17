package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type permissionListResponse struct {
	Permissions []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
		Code string `json:"code"`
	} `json:"permissions"`
}

type roleListResponse struct {
	Roles []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
		Code string `json:"code"`
	} `json:"roles"`
}

type roleOperationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type checkPermissionResponse struct {
	HasPermission bool `json:"has_permission"`
}

func TestAdmin_PermissionsAndRoles(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin permissions/roles test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// permissions
	respPerm, bodyPerm, err := c.DoJSON("GET", "/api/admin/permissions", nil, admin.Token)
	if err != nil {
		t.Fatalf("get permissions http error: %v", err)
	}
	if respPerm.StatusCode != 200 {
		t.Fatalf("get permissions status=%d body=%s", respPerm.StatusCode, string(bodyPerm))
	}
	var perms permissionListResponse
	if err := testutil.DecodeJSON(bodyPerm, &perms); err != nil {
		t.Fatalf("decode permissions: %v body=%s", err, string(bodyPerm))
	}
	if len(perms.Permissions) == 0 {
		t.Fatalf("expected permissions non-empty: body=%s", string(bodyPerm))
	}
	if perms.Permissions[0].ID == "" || perms.Permissions[0].Code == "" {
		t.Fatalf("expected permission id/code: body=%s", string(bodyPerm))
	}

	// roles
	respRoles, bodyRoles, err := c.DoJSON("GET", "/api/admin/roles", nil, admin.Token)
	if err != nil {
		t.Fatalf("get roles http error: %v", err)
	}
	if respRoles.StatusCode != 200 {
		t.Fatalf("get roles status=%d body=%s", respRoles.StatusCode, string(bodyRoles))
	}
	var roles roleListResponse
	if err := testutil.DecodeJSON(bodyRoles, &roles); err != nil {
		t.Fatalf("decode roles: %v body=%s", err, string(bodyRoles))
	}
	if len(roles.Roles) == 0 {
		t.Fatalf("expected roles non-empty: body=%s", string(bodyRoles))
	}
	if roles.Roles[0].ID == "" || roles.Roles[0].Code == "" {
		t.Fatalf("expected role id/code: body=%s", string(bodyRoles))
	}

	// create role: name empty => success=false (handler 简化版本不会返回 4xx)
	respCreate1, bodyCreate1, err := c.DoJSON("POST", "/api/admin/roles", map[string]any{
		"name":           "",
		"code":           "go_test_role",
		"permission_ids": []string{},
	}, admin.Token)
	if err != nil {
		t.Fatalf("create role (empty name) http error: %v", err)
	}
	if respCreate1.StatusCode != 200 {
		t.Fatalf("create role (empty name) status=%d body=%s", respCreate1.StatusCode, string(bodyCreate1))
	}
	var op1 roleOperationResponse
	if err := testutil.DecodeJSON(bodyCreate1, &op1); err != nil {
		t.Fatalf("decode create role (empty name): %v body=%s", err, string(bodyCreate1))
	}
	if op1.Success {
		t.Fatalf("expected create role (empty name) success=false, body=%s", string(bodyCreate1))
	}

	// create role: code empty => success=false
	respCreate2, bodyCreate2, err := c.DoJSON("POST", "/api/admin/roles", map[string]any{
		"name":           "Go Test Role",
		"code":           "",
		"permission_ids": []string{},
	}, admin.Token)
	if err != nil {
		t.Fatalf("create role (empty code) http error: %v", err)
	}
	if respCreate2.StatusCode != 200 {
		t.Fatalf("create role (empty code) status=%d body=%s", respCreate2.StatusCode, string(bodyCreate2))
	}
	var op2 roleOperationResponse
	if err := testutil.DecodeJSON(bodyCreate2, &op2); err != nil {
		t.Fatalf("decode create role (empty code): %v body=%s", err, string(bodyCreate2))
	}
	if op2.Success {
		t.Fatalf("expected create role (empty code) success=false, body=%s", string(bodyCreate2))
	}

	// create role: ok
	respCreate3, bodyCreate3, err := c.DoJSON("POST", "/api/admin/roles", map[string]any{
		"name":           "Go Test Role",
		"code":           "go_test_role",
		"permission_ids": []string{},
	}, admin.Token)
	if err != nil {
		t.Fatalf("create role http error: %v", err)
	}
	if respCreate3.StatusCode != 200 {
		t.Fatalf("create role status=%d body=%s", respCreate3.StatusCode, string(bodyCreate3))
	}
	var op3 roleOperationResponse
	if err := testutil.DecodeJSON(bodyCreate3, &op3); err != nil {
		t.Fatalf("decode create role: %v body=%s", err, string(bodyCreate3))
	}
	if !op3.Success {
		t.Fatalf("expected create role success=true, body=%s", string(bodyCreate3))
	}

	// update system role => success=false
	respUpd, bodyUpd, err := c.DoJSON("PATCH", "/api/admin/roles/1", map[string]any{
		"name":           "Should Fail",
		"permission_ids": []string{},
	}, admin.Token)
	if err != nil {
		t.Fatalf("update role http error: %v", err)
	}
	if respUpd.StatusCode != 200 {
		t.Fatalf("update role status=%d body=%s", respUpd.StatusCode, string(bodyUpd))
	}
	var opUpd roleOperationResponse
	if err := testutil.DecodeJSON(bodyUpd, &opUpd); err != nil {
		t.Fatalf("decode update role: %v body=%s", err, string(bodyUpd))
	}
	if opUpd.Success {
		t.Fatalf("expected update system role success=false, body=%s", string(bodyUpd))
	}

	// delete system role => success=false
	respDel, bodyDel, err := c.DoJSON("DELETE", "/api/admin/roles/1", map[string]any{}, admin.Token)
	if err != nil {
		t.Fatalf("delete role http error: %v", err)
	}
	if respDel.StatusCode != 200 {
		t.Fatalf("delete role status=%d body=%s", respDel.StatusCode, string(bodyDel))
	}
	var opDel roleOperationResponse
	if err := testutil.DecodeJSON(bodyDel, &opDel); err != nil {
		t.Fatalf("decode delete role: %v body=%s", err, string(bodyDel))
	}
	if opDel.Success {
		t.Fatalf("expected delete system role success=false, body=%s", string(bodyDel))
	}

	// permission check: invalid user_id => 400
	respBad, bodyBad, err := c.DoJSON("POST", "/api/admin/permissions/check", map[string]any{
		"user_id":         "not-a-uuid",
		"permission_code": "user:view",
	}, admin.Token)
	if err != nil {
		t.Fatalf("check permission (bad user) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected check permission (bad user) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}

	// permission check: ok
	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	respOK, bodyOK, err := c.DoJSON("POST", "/api/admin/permissions/check", map[string]any{
		"user_id":         user.ID,
		"permission_code": "user:view",
	}, admin.Token)
	if err != nil {
		t.Fatalf("check permission http error: %v", err)
	}
	if respOK.StatusCode != 200 {
		t.Fatalf("check permission status=%d body=%s", respOK.StatusCode, string(bodyOK))
	}
	var chk checkPermissionResponse
	if err := testutil.DecodeJSON(bodyOK, &chk); err != nil {
		t.Fatalf("decode check permission: %v body=%s", err, string(bodyOK))
	}
	if !chk.HasPermission {
		t.Fatalf("expected has_permission=true, body=%s", string(bodyOK))
	}

	// 非管理员访问 admin-only 路由必须 403
	login := testutil.Login(t, c, user.Username, pass)
	respForbidden, bodyForbidden, err := c.DoJSON("GET", "/api/admin/permissions", nil, login.Token)
	if err != nil {
		t.Fatalf("get permissions (non-admin) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected non-admin status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}
}
