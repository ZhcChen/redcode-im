package admin_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"slices"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminLoginResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
	User         struct {
		ID             string   `json:"id"`
		Username       string   `json:"username"`
		RoleCodes      []string `json:"roleCodes"`
		PermissionKeys []string `json:"permissionKeys"`
		IsSuperAdmin   bool     `json:"isSuperAdmin"`
	} `json:"user"`
}

type adminMeResponse struct {
	ID             string   `json:"id"`
	Username       string   `json:"username"`
	RoleCodes      []string `json:"roleCodes"`
	PermissionKeys []string `json:"permissionKeys"`
	IsSuperAdmin   bool     `json:"isSuperAdmin"`
}

type permissionListResponse struct {
	Permissions []struct {
		ID   string `json:"id"`
		Code string `json:"code"`
	} `json:"permissions"`
}

type roleListResponse struct {
	Roles []struct {
		ID          string `json:"id"`
		Code        string `json:"code"`
		Permissions []struct {
			ID   string `json:"id"`
			Code string `json:"code"`
		} `json:"permissions"`
	} `json:"roles"`
}

type roleResponse struct {
	ID          string `json:"id"`
	Code        string `json:"code"`
	Permissions []struct {
		ID string `json:"id"`
	} `json:"permissions"`
}

type adminUserResponse struct {
	ID string `json:"id"`
}

type rolePermissionAssignmentResponse struct {
	RoleID        string   `json:"roleId"`
	PermissionIDs []string `json:"permissionIds"`
}

type adminUserRoleAssignmentResponse struct {
	AdminUserID string   `json:"adminUserId"`
	RoleIDs     []string `json:"roleIds"`
}

type checkPermissionResponse struct {
	HasPermission bool `json:"has_permission"`
}

func initDefaultAdmin(t *testing.T, c *testutil.Client) {
	t.Helper()
	statusResp, err := c.HTTP.Get(c.BaseURL + "/api/admin/bootstrap/status")
	if err != nil {
		t.Fatalf("get bootstrap status failed: %v", err)
	}
	defer statusResp.Body.Close()

	var status struct {
		BootstrapRequired bool `json:"bootstrap_required"`
	}
	if err := json.NewDecoder(statusResp.Body).Decode(&status); err != nil {
		t.Fatalf("decode bootstrap status failed: %v", err)
	}

	if !status.BootstrapRequired {
		return
	}

	payload := []byte(`{"username":"admin","password":"BhgNKtC1RbOBj1sCVKmt9Rwx","display_name":"系统管理员"}`)
	resp, err := c.HTTP.Post(c.BaseURL+"/api/admin/bootstrap/init", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("bootstrap init failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("bootstrap init expect 200, got %d: %s", resp.StatusCode, string(body))
	}
}

func adminLoginRaw(t *testing.T, c *testutil.Client) adminLoginResponse {
	t.Helper()
	payload := []byte(`{"username":"admin","password":"BhgNKtC1RbOBj1sCVKmt9Rwx"}`)
	resp, err := c.HTTP.Post(c.BaseURL+"/auth/admin/login", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("admin login failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("admin login expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var login adminLoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&login); err != nil {
		t.Fatalf("decode admin login response failed: %v", err)
	}
	return login
}

func TestAdminAuthSnapshotAndRBACContracts(t *testing.T) {
	c := testutil.NewClient()
	initDefaultAdmin(t, c)

	login := adminLoginRaw(t, c)
	if login.Token == "" {
		t.Fatalf("admin login token is empty")
	}
	if !login.User.IsSuperAdmin {
		t.Fatalf("default admin should be super admin: %+v", login.User)
	}
	if len(login.User.RoleCodes) == 0 {
		t.Fatalf("admin login missing roleCodes: %+v", login.User)
	}
	if len(login.User.PermissionKeys) == 0 {
		t.Fatalf("admin login missing permissionKeys: %+v", login.User)
	}

	meReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/auth/admin/me", login.Token, nil)
	meResp, err := c.HTTP.Do(meReq)
	if err != nil {
		t.Fatalf("get admin me failed: %v", err)
	}
	defer meResp.Body.Close()
	if meResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(meResp.Body)
		t.Fatalf("admin me expect 200, got %d: %s", meResp.StatusCode, string(body))
	}

	var me adminMeResponse
	if err := json.NewDecoder(meResp.Body).Decode(&me); err != nil {
		t.Fatalf("decode admin me failed: %v", err)
	}
	if !me.IsSuperAdmin || len(me.RoleCodes) == 0 || len(me.PermissionKeys) == 0 {
		t.Fatalf("admin me missing RBAC snapshot: %+v", me)
	}

	permissionsReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/permissions", login.Token, nil)
	permissionsResp, err := c.HTTP.Do(permissionsReq)
	if err != nil {
		t.Fatalf("get permissions failed: %v", err)
	}
	defer permissionsResp.Body.Close()
	if permissionsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(permissionsResp.Body)
		t.Fatalf("permissions expect 200, got %d: %s", permissionsResp.StatusCode, string(body))
	}

	var permissions permissionListResponse
	if err := json.NewDecoder(permissionsResp.Body).Decode(&permissions); err != nil {
		t.Fatalf("decode permissions failed: %v", err)
	}
	if len(permissions.Permissions) < 3 {
		t.Fatalf("permissions should come from database and not be a tiny placeholder list: %+v", permissions)
	}

	rolesReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/roles", login.Token, nil)
	rolesResp, err := c.HTTP.Do(rolesReq)
	if err != nil {
		t.Fatalf("get roles failed: %v", err)
	}
	defer rolesResp.Body.Close()
	if rolesResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(rolesResp.Body)
		t.Fatalf("roles expect 200, got %d: %s", rolesResp.StatusCode, string(body))
	}

	var roles roleListResponse
	if err := json.NewDecoder(rolesResp.Body).Decode(&roles); err != nil {
		t.Fatalf("decode roles failed: %v", err)
	}
	if len(roles.Roles) == 0 {
		t.Fatalf("roles list is empty")
	}

	var foundSuperAdmin bool
	for _, role := range roles.Roles {
		if role.Code == "super_admin" {
			foundSuperAdmin = true
			if len(role.Permissions) == 0 {
				t.Fatalf("super_admin role should contain permissions")
			}
		}
	}
	if !foundSuperAdmin {
		t.Fatalf("roles list missing super_admin role: %+v", roles)
	}
}

func TestAdminRolePermissionAndUserRoleAssignments(t *testing.T) {
	c := testutil.NewClient()
	initDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c)

	permissionsReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/permissions", admin.Token, nil)
	permissionsResp, err := c.HTTP.Do(permissionsReq)
	if err != nil {
		t.Fatalf("get permissions failed: %v", err)
	}
	defer permissionsResp.Body.Close()
	if permissionsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(permissionsResp.Body)
		t.Fatalf("permissions expect 200, got %d: %s", permissionsResp.StatusCode, string(body))
	}

	var permissions permissionListResponse
	if err := json.NewDecoder(permissionsResp.Body).Decode(&permissions); err != nil {
		t.Fatalf("decode permissions failed: %v", err)
	}
	if len(permissions.Permissions) < 2 {
		t.Fatalf("need at least 2 permissions for assignment test: %+v", permissions)
	}

	roleSuffix := testutil.UniqueUsername("rbac")
	roleCode := fmt.Sprintf("auditor_%s", roleSuffix)
	createRolePayload := map[string]any{
		"name":           fmt.Sprintf("审计员%s", roleSuffix),
		"code":           roleCode,
		"description":    "RBAC E2E role",
		"permission_ids": []string{permissions.Permissions[0].ID},
	}
	createRoleReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/api/admin/roles", admin.Token, createRolePayload)
	createRoleResp, err := c.HTTP.Do(createRoleReq)
	if err != nil {
		t.Fatalf("create role failed: %v", err)
	}
	defer createRoleResp.Body.Close()
	if createRoleResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createRoleResp.Body)
		t.Fatalf("create role expect 200, got %d: %s", createRoleResp.StatusCode, string(body))
	}

	var createdRole roleResponse
	if err := json.NewDecoder(createRoleResp.Body).Decode(&createdRole); err != nil {
		t.Fatalf("decode created role failed: %v", err)
	}
	if createdRole.ID == "" || createdRole.Code != roleCode {
		t.Fatalf("unexpected created role: %+v", createdRole)
	}

	getRolePermissionsReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/roles/"+createdRole.ID+"/permissions", admin.Token, nil)
	getRolePermissionsResp, err := c.HTTP.Do(getRolePermissionsReq)
	if err != nil {
		t.Fatalf("get role permissions failed: %v", err)
	}
	defer getRolePermissionsResp.Body.Close()
	if getRolePermissionsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(getRolePermissionsResp.Body)
		t.Fatalf("get role permissions expect 200, got %d: %s", getRolePermissionsResp.StatusCode, string(body))
	}

	var rolePermissions rolePermissionAssignmentResponse
	if err := json.NewDecoder(getRolePermissionsResp.Body).Decode(&rolePermissions); err != nil {
		t.Fatalf("decode role permission assignment failed: %v", err)
	}
	if len(rolePermissions.PermissionIDs) != 1 || rolePermissions.PermissionIDs[0] != permissions.Permissions[0].ID {
		t.Fatalf("unexpected initial role permissions: %+v", rolePermissions)
	}

	updateRolePermissionsReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPut,
		c.BaseURL+"/api/admin/roles/"+createdRole.ID+"/permissions",
		admin.Token,
		map[string]any{"permission_ids": []string{permissions.Permissions[1].ID}},
	)
	updateRolePermissionsResp, err := c.HTTP.Do(updateRolePermissionsReq)
	if err != nil {
		t.Fatalf("update role permissions failed: %v", err)
	}
	defer updateRolePermissionsResp.Body.Close()
	if updateRolePermissionsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(updateRolePermissionsResp.Body)
		t.Fatalf("update role permissions expect 200, got %d: %s", updateRolePermissionsResp.StatusCode, string(body))
	}

	if err := json.NewDecoder(updateRolePermissionsResp.Body).Decode(&rolePermissions); err != nil {
		t.Fatalf("decode updated role permissions failed: %v", err)
	}
	if len(rolePermissions.PermissionIDs) != 1 || rolePermissions.PermissionIDs[0] != permissions.Permissions[1].ID {
		t.Fatalf("unexpected updated role permissions: %+v", rolePermissions)
	}

	adminUsername := fmt.Sprintf("rbac_admin_%s", testutil.UniqueUsername("rbac"))
	createAdminReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/admin-users",
		admin.Token,
		map[string]any{
			"username": adminUsername,
			"email":    adminUsername + "@example.com",
			"password": "Admin12345",
		},
	)
	createAdminResp, err := c.HTTP.Do(createAdminReq)
	if err != nil {
		t.Fatalf("create admin user failed: %v", err)
	}
	defer createAdminResp.Body.Close()
	if createAdminResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createAdminResp.Body)
		t.Fatalf("create admin user expect 200, got %d: %s", createAdminResp.StatusCode, string(body))
	}

	var createdAdmin adminUserResponse
	if err := json.NewDecoder(createAdminResp.Body).Decode(&createdAdmin); err != nil {
		t.Fatalf("decode created admin user failed: %v", err)
	}
	if createdAdmin.ID == "" {
		t.Fatalf("created admin user id is empty: %+v", createdAdmin)
	}

	assignRolesReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPut,
		c.BaseURL+"/api/admin/admin-users/"+createdAdmin.ID+"/roles",
		admin.Token,
		map[string]any{"role_ids": []string{createdRole.ID}},
	)
	assignRolesResp, err := c.HTTP.Do(assignRolesReq)
	if err != nil {
		t.Fatalf("assign admin user roles failed: %v", err)
	}
	defer assignRolesResp.Body.Close()
	if assignRolesResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(assignRolesResp.Body)
		t.Fatalf("assign admin user roles expect 200, got %d: %s", assignRolesResp.StatusCode, string(body))
	}

	var adminRoles adminUserRoleAssignmentResponse
	if err := json.NewDecoder(assignRolesResp.Body).Decode(&adminRoles); err != nil {
		t.Fatalf("decode assigned admin roles failed: %v", err)
	}
	if len(adminRoles.RoleIDs) != 1 || adminRoles.RoleIDs[0] != createdRole.ID {
		t.Fatalf("unexpected assigned roles: %+v", adminRoles)
	}

	getAdminRolesReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/admin-users/"+createdAdmin.ID+"/roles", admin.Token, nil)
	getAdminRolesResp, err := c.HTTP.Do(getAdminRolesReq)
	if err != nil {
		t.Fatalf("get admin user roles failed: %v", err)
	}
	defer getAdminRolesResp.Body.Close()
	if getAdminRolesResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(getAdminRolesResp.Body)
		t.Fatalf("get admin user roles expect 200, got %d: %s", getAdminRolesResp.StatusCode, string(body))
	}

	if err := json.NewDecoder(getAdminRolesResp.Body).Decode(&adminRoles); err != nil {
		t.Fatalf("decode admin roles failed: %v", err)
	}
	if len(adminRoles.RoleIDs) != 1 || adminRoles.RoleIDs[0] != createdRole.ID {
		t.Fatalf("unexpected persisted admin roles: %+v", adminRoles)
	}

	createdAdminLoginPayload := []byte(fmt.Sprintf(`{"username":"%s","password":"Admin12345"}`, adminUsername))
	createdAdminLoginResp, err := c.HTTP.Post(c.BaseURL+"/auth/admin/login", "application/json", bytes.NewReader(createdAdminLoginPayload))
	if err != nil {
		t.Fatalf("created admin login failed: %v", err)
	}
	defer createdAdminLoginResp.Body.Close()
	if createdAdminLoginResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createdAdminLoginResp.Body)
		t.Fatalf("created admin login expect 200, got %d: %s", createdAdminLoginResp.StatusCode, string(body))
	}

	var createdAdminLogin adminLoginResponse
	if err := json.NewDecoder(createdAdminLoginResp.Body).Decode(&createdAdminLogin); err != nil {
		t.Fatalf("decode created admin login response failed: %v", err)
	}
	if createdAdminLogin.User.IsSuperAdmin {
		t.Fatalf("created admin should not be super admin: %+v", createdAdminLogin.User)
	}
	if !slices.Contains(createdAdminLogin.User.RoleCodes, createdRole.Code) {
		t.Fatalf("created admin login missing assigned role code %s: %+v", createdRole.Code, createdAdminLogin.User)
	}
	if !slices.Contains(createdAdminLogin.User.PermissionKeys, permissions.Permissions[1].Code) {
		t.Fatalf("created admin login missing assigned permission code %s: %+v", permissions.Permissions[1].Code, createdAdminLogin.User)
	}
	if slices.Contains(createdAdminLogin.User.PermissionKeys, permissions.Permissions[0].Code) {
		t.Fatalf("created admin login should not keep stale permission code %s after role update: %+v", permissions.Permissions[0].Code, createdAdminLogin.User)
	}

	checkGrantedReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/permissions/check",
		admin.Token,
		map[string]any{
			"user_id":         createdAdmin.ID,
			"permission_code": permissions.Permissions[1].Code,
		},
	)
	checkGrantedResp, err := c.HTTP.Do(checkGrantedReq)
	if err != nil {
		t.Fatalf("check granted permission failed: %v", err)
	}
	defer checkGrantedResp.Body.Close()
	if checkGrantedResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(checkGrantedResp.Body)
		t.Fatalf("check granted permission expect 200, got %d: %s", checkGrantedResp.StatusCode, string(body))
	}

	var granted checkPermissionResponse
	if err := json.NewDecoder(checkGrantedResp.Body).Decode(&granted); err != nil {
		t.Fatalf("decode granted permission response failed: %v", err)
	}
	if !granted.HasPermission {
		t.Fatalf("created admin should have permission %s", permissions.Permissions[1].Code)
	}

	checkDeniedReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/api/admin/permissions/check",
		admin.Token,
		map[string]any{
			"user_id":         createdAdmin.ID,
			"permission_code": permissions.Permissions[0].Code,
		},
	)
	checkDeniedResp, err := c.HTTP.Do(checkDeniedReq)
	if err != nil {
		t.Fatalf("check denied permission failed: %v", err)
	}
	defer checkDeniedResp.Body.Close()
	if checkDeniedResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(checkDeniedResp.Body)
		t.Fatalf("check denied permission expect 200, got %d: %s", checkDeniedResp.StatusCode, string(body))
	}

	var denied checkPermissionResponse
	if err := json.NewDecoder(checkDeniedResp.Body).Decode(&denied); err != nil {
		t.Fatalf("decode denied permission response failed: %v", err)
	}
	if denied.HasPermission {
		t.Fatalf("created admin should not have stale permission %s", permissions.Permissions[0].Code)
	}
}
