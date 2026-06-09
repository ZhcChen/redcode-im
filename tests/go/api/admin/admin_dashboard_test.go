package admin_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestAdminLoginDashboardAndUserList_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	statsReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/dashboard/stats", admin.Token, nil)
	statsResp, err := c.HTTP.Do(statsReq)
	if err != nil {
		t.Fatalf("get dashboard stats failed: %v", err)
	}
	defer statsResp.Body.Close()
	if statsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(statsResp.Body)
		t.Fatalf("dashboard stats expect 200, got %d: %s", statsResp.StatusCode, string(body))
	}

	var stats map[string]any
	if err := json.NewDecoder(statsResp.Body).Decode(&stats); err != nil {
		t.Fatalf("decode dashboard stats failed: %v", err)
	}
	if len(stats) == 0 {
		t.Fatalf("dashboard stats response is empty")
	}

	usersReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/users?page=1&page_size=20", admin.Token, nil)
	usersResp, err := c.HTTP.Do(usersReq)
	if err != nil {
		t.Fatalf("get admin user list failed: %v", err)
	}
	defer usersResp.Body.Close()
	if usersResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(usersResp.Body)
		t.Fatalf("admin user list expect 200, got %d: %s", usersResp.StatusCode, string(body))
	}

	var usersPayload map[string]any
	if err := json.NewDecoder(usersResp.Body).Decode(&usersPayload); err != nil {
		t.Fatalf("decode admin user list failed: %v", err)
	}
	if _, ok := usersPayload["users"]; !ok {
		t.Fatalf("admin user list response missing 'users' field: %+v", usersPayload)
	}
}
