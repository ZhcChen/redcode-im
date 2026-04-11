package admin_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestAdminBootstrapStatusAndRepeatInitRejected(t *testing.T) {
	c := testutil.NewClient()
	initDefaultAdmin(t, c)

	statusResp, err := c.HTTP.Get(c.BaseURL + "/api/admin/bootstrap/status")
	if err != nil {
		t.Fatalf("get bootstrap status after init failed: %v", err)
	}
	defer statusResp.Body.Close()
	if statusResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(statusResp.Body)
		t.Fatalf("get bootstrap status after init expect 200, got %d: %s", statusResp.StatusCode, string(body))
	}

	var status struct {
		BootstrapRequired bool `json:"bootstrap_required"`
	}
	if err := json.NewDecoder(statusResp.Body).Decode(&status); err != nil {
		t.Fatalf("decode bootstrap status after init failed: %v", err)
	}
	if status.BootstrapRequired {
		t.Fatalf("bootstrap should not be required after first admin is initialized")
	}

	payload := []byte(`{"username":"admin","password":"BhgNKtC1RbOBj1sCVKmt9Rwx","display_name":"系统管理员"}`)
	retryResp, err := c.HTTP.Post(c.BaseURL+"/api/admin/bootstrap/init", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("repeat bootstrap init request failed: %v", err)
	}
	defer retryResp.Body.Close()
	if retryResp.StatusCode != http.StatusConflict {
		body, _ := io.ReadAll(retryResp.Body)
		t.Fatalf("repeat bootstrap init expect 409, got %d: %s", retryResp.StatusCode, string(body))
	}

	var errPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(retryResp.Body).Decode(&errPayload); err != nil {
		t.Fatalf("decode repeat bootstrap init response failed: %v", err)
	}
	if errPayload.Code != 40901 {
		t.Fatalf("repeat bootstrap init error code mismatch: %+v", errPayload)
	}
	if errPayload.Message != "管理员已初始化，不能重复创建首个超级管理员" {
		t.Fatalf("repeat bootstrap init error message mismatch: %+v", errPayload)
	}
}
