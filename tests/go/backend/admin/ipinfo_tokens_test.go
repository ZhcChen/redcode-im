package admin_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type ipinfoTokenInfo struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Token       string  `json:"token"`
	MonthlyLimit int    `json:"monthlyLimit"`
	UsedCount   int     `json:"usedCount"`
	ResetDate   string  `json:"resetDate"`
	Status      string  `json:"status"`
	LastUsedAt  *string `json:"lastUsedAt"`
	CreatedAt   string  `json:"createdAt"`
	UpdatedAt   string  `json:"updatedAt"`
}

type tokenListResponse struct {
	List  []ipinfoTokenInfo `json:"list"`
	Total int64             `json:"total"`
}

func TestAdmin_IpinfoTokens_CRUD(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip ipinfo tokens test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respList, bodyList, err := c.DoJSON("GET", "/api/admin/ipinfo-tokens?page=1&page_size=10", nil, admin.Token)
	if err != nil {
		t.Fatalf("list ipinfo tokens http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list ipinfo tokens status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list tokenListResponse
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode ipinfo tokens list: %v body=%s", err, string(bodyList))
	}
	if list.Total < 0 {
		t.Fatalf("expected total >=0, got %d", list.Total)
	}

	name := "go-ipinfo-" + time.Now().Format("150405.000000000")
	tokenValue := "tok-" + time.Now().Format("150405.000000000")

	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/ipinfo-tokens", map[string]any{
		"name":          name,
		"token":         tokenValue,
		"monthly_limit": 123,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create ipinfo token http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create ipinfo token status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created ipinfoTokenInfo
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode created ipinfo token: %v body=%s", err, string(bodyCreate))
	}
	if created.ID == "" || created.Name != name || created.Token != tokenValue {
		t.Fatalf("unexpected created token: %+v body=%s", created, string(bodyCreate))
	}
	if created.MonthlyLimit != 123 {
		t.Fatalf("expected monthlyLimit=123, got %d body=%s", created.MonthlyLimit, string(bodyCreate))
	}
	if created.Status == "" || created.ResetDate == "" {
		t.Fatalf("expected status/resetDate non-empty: %+v body=%s", created, string(bodyCreate))
	}

	respUpd, bodyUpd, err := c.DoJSON("PATCH", "/api/admin/ipinfo-tokens/"+created.ID, map[string]any{
		"monthly_limit": 456,
		"status":        "exhausted",
	}, admin.Token)
	if err != nil {
		t.Fatalf("update ipinfo token http error: %v", err)
	}
	if respUpd.StatusCode != 200 {
		t.Fatalf("update ipinfo token status=%d body=%s", respUpd.StatusCode, string(bodyUpd))
	}
	var updated ipinfoTokenInfo
	if err := testutil.DecodeJSON(bodyUpd, &updated); err != nil {
		t.Fatalf("decode updated ipinfo token: %v body=%s", err, string(bodyUpd))
	}
	if updated.ID != created.ID || updated.MonthlyLimit != 456 || updated.Status != "exhausted" {
		t.Fatalf("unexpected updated token: %+v body=%s", updated, string(bodyUpd))
	}

	respReset, bodyReset, err := c.DoJSON("POST", "/api/admin/ipinfo-tokens/"+created.ID+"/reset", map[string]any{}, admin.Token)
	if err != nil {
		t.Fatalf("reset ipinfo token usage http error: %v", err)
	}
	if respReset.StatusCode != 200 {
		t.Fatalf("reset ipinfo token usage status=%d body=%s", respReset.StatusCode, string(bodyReset))
	}
	var reset ipinfoTokenInfo
	if err := testutil.DecodeJSON(bodyReset, &reset); err != nil {
		t.Fatalf("decode reset ipinfo token: %v body=%s", err, string(bodyReset))
	}
	if reset.ID != created.ID || reset.UsedCount != 0 || reset.Status != "active" {
		t.Fatalf("unexpected reset token: %+v body=%s", reset, string(bodyReset))
	}

	respDel, bodyDel, err := c.DoJSON("DELETE", "/api/admin/ipinfo-tokens/"+created.ID, nil, admin.Token)
	if err != nil {
		t.Fatalf("delete ipinfo token http error: %v", err)
	}
	if respDel.StatusCode != 204 {
		t.Fatalf("expected delete ipinfo token status=204, got %d body=%s", respDel.StatusCode, string(bodyDel))
	}
}

