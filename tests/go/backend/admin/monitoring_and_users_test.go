package admin_test

import (
	"net/url"
	"os"
	"slices"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type nodeMonitorInfo struct {
	NodeID         string  `json:"nodeId"`
	Address        string  `json:"address"`
	ConnectedUsers int     `json:"connectedUsers"`
	ActiveRooms    int     `json:"activeRooms"`
	CPUUsage       float64 `json:"cpuUsage"`
	MemoryUsage    float64 `json:"memoryUsage"`
	DiskUsage      float64 `json:"diskUsage"`
	CPUCount       int     `json:"cpuCount"`
	TotalMemory    uint64  `json:"totalMemory"`
	LastHeartbeat  string  `json:"lastHeartbeat"`
	StartedAt      string  `json:"startedAt"`
}

type apiMetricsResponse struct {
	Metrics  []map[string]any `json:"metrics"`
	TopAvg   []map[string]any `json:"top_avg"`
	TopCount []map[string]any `json:"top_count"`
	Total    int              `json:"total"`
	Page     int              `json:"page"`
	PageSize int              `json:"page_size"`
}

type adminUserListResponse struct {
	Users []struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Status   string `json:"status"`
	} `json:"users"`
	Total    int `json:"total"`
	Page     int `json:"page"`
	PageSize int `json:"page_size"`
}

func TestAdmin_NodesMonitor_AndPerformanceMetrics(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin monitoring test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respNodes, bodyNodes, err := c.DoJSON("GET", "/api/admin/nodes/monitor", nil, admin.Token)
	if err != nil {
		t.Fatalf("nodes monitor http error: %v", err)
	}
	if respNodes.StatusCode != 200 {
		t.Fatalf("nodes monitor status=%d body=%s", respNodes.StatusCode, string(bodyNodes))
	}
	var nodes []nodeMonitorInfo
	if err := testutil.DecodeJSON(bodyNodes, &nodes); err != nil {
		t.Fatalf("decode nodes monitor: %v body=%s", err, string(bodyNodes))
	}

	respPerf, bodyPerf, err := c.DoJSON("GET", "/api/admin/metrics/performance?page=1&page_size=10", nil, admin.Token)
	if err != nil {
		t.Fatalf("performance metrics http error: %v", err)
	}
	if respPerf.StatusCode != 200 {
		t.Fatalf("performance metrics status=%d body=%s", respPerf.StatusCode, string(bodyPerf))
	}
	var perf apiMetricsResponse
	if err := testutil.DecodeJSON(bodyPerf, &perf); err != nil {
		t.Fatalf("decode performance metrics: %v body=%s", err, string(bodyPerf))
	}
	if perf.Page <= 0 || perf.PageSize <= 0 {
		t.Fatalf("expected page/page_size > 0, got page=%d page_size=%d body=%s", perf.Page, perf.PageSize, string(bodyPerf))
	}
	if perf.Total < 0 {
		t.Fatalf("expected total >=0, got %d body=%s", perf.Total, string(bodyPerf))
	}
}

func TestAdmin_Users_ListFilterAndStatus_BanBlocksLogin(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin users list/status test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	// user 初始应可登录
	login := testutil.Login(t, c, user.Username, pass)
	if login.Token == "" {
		t.Fatalf("login missing token: %+v", login)
	}

	q := url.QueryEscape(user.Username)
	respList, bodyList, err := c.DoJSON("GET", "/api/admin/users?page=1&page_size=50&username="+q, nil, admin.Token)
	if err != nil {
		t.Fatalf("list users http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list users status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var users adminUserListResponse
	if err := testutil.DecodeJSON(bodyList, &users); err != nil {
		t.Fatalf("decode users list: %v body=%s", err, string(bodyList))
	}
	if users.Page <= 0 || users.PageSize <= 0 {
		t.Fatalf("expected page/page_size > 0, got page=%d page_size=%d body=%s", users.Page, users.PageSize, string(bodyList))
	}
	if !slices.ContainsFunc(users.Users, func(u struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Status   string `json:"status"`
	}) bool { return u.ID == user.ID }) {
		t.Fatalf("expected user in admin list, got %+v", users.Users)
	}

	// invalid status should be 400
	respBad, _, err := c.DoJSON("PATCH", "/api/admin/users/"+user.ID+"/status", map[string]any{
		"status": "unknown",
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user status (bad) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected update user status (bad)=400, got %d", respBad.StatusCode)
	}

	// ban
	respBan, bodyBan, err := c.DoJSON("PATCH", "/api/admin/users/"+user.ID+"/status", map[string]any{
		"status": "banned",
	}, admin.Token)
	if err != nil {
		t.Fatalf("ban user http error: %v", err)
	}
	if respBan.StatusCode != 200 {
		t.Fatalf("ban user status=%d body=%s", respBan.StatusCode, string(bodyBan))
	}

	// banned user 登录应被拒绝
	respLogin, bodyLogin, err := c.DoJSON("POST", "/auth/login", map[string]any{
		"username": user.Username,
		"password": pass,
	}, "")
	if err != nil {
		t.Fatalf("login banned user http error: %v", err)
	}
	if respLogin.StatusCode != 403 {
		t.Fatalf("expected banned user login=403, got %d body=%s", respLogin.StatusCode, string(bodyLogin))
	}
}

