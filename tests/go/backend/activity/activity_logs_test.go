package activity_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type heartbeatLog struct {
	ID           string `json:"id"`
	UserID       string `json:"user_id"`
	IPAddress    string `json:"ip_address"`
	ConnectionID string `json:"connection_id"`
}

type loginHistoryLog struct {
	ID          string  `json:"id"`
	UserID      string  `json:"user_id"`
	IPAddress   string  `json:"ip_address"`
	LoginMethod string  `json:"login_method"`
	Success     bool    `json:"success"`
	LogoutAt    *string `json:"logout_at"`
}

func TestActivityLogs_CreateAndQuery(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	// create heartbeat
	connID := "go-conn-" + time.Now().Format("150405.000000000")
	respHB, bodyHB, err := c.DoJSON("POST", "/activity/heartbeat", map[string]any{
		"user_id":       user.ID,
		"ip_address":    "127.0.0.1",
		"user_agent":    "go-test",
		"connection_id": connID,
		"node_id":       "test-node",
		"device_info": map[string]any{
			"platform": "go",
		},
	}, login.Token)
	if err != nil {
		t.Fatalf("create heartbeat http error: %v", err)
	}
	if respHB.StatusCode != 200 {
		t.Fatalf("create heartbeat status=%d body=%s", respHB.StatusCode, string(bodyHB))
	}
	var hb heartbeatLog
	if err := testutil.DecodeJSON(bodyHB, &hb); err != nil {
		t.Fatalf("decode heartbeat: %v body=%s", err, string(bodyHB))
	}
	if hb.ID == "" || hb.UserID != user.ID || hb.IPAddress != "127.0.0.1" || hb.ConnectionID != connID {
		t.Fatalf("unexpected heartbeat log: %+v body=%s", hb, string(bodyHB))
	}

	// query heartbeat logs
	respHBList, bodyHBList, err := c.DoJSON("GET", "/users/"+user.ID+"/activity/heartbeat-logs?limit=10&offset=0", nil, login.Token)
	if err != nil {
		t.Fatalf("list heartbeat logs http error: %v", err)
	}
	if respHBList.StatusCode != 200 {
		t.Fatalf("list heartbeat logs status=%d body=%s", respHBList.StatusCode, string(bodyHBList))
	}
	var hbLogs []heartbeatLog
	if err := testutil.DecodeJSON(bodyHBList, &hbLogs); err != nil {
		t.Fatalf("decode heartbeat logs: %v body=%s", err, string(bodyHBList))
	}
	foundHB := false
	for _, item := range hbLogs {
		if item.ID == hb.ID {
			foundHB = true
			break
		}
	}
	if !foundHB {
		t.Fatalf("expected heartbeat id=%s in list, body=%s", hb.ID, string(bodyHBList))
	}

	// create login history
	respLogin, bodyLogin, err := c.DoJSON("POST", "/activity/login", map[string]any{
		"user_id":        user.ID,
		"ip_address":     "127.0.0.1",
		"user_agent":     "go-test",
		"login_method":   "password",
		"success":        true,
		"failure_reason": nil,
		"device_info": map[string]any{
			"platform": "go",
		},
	}, login.Token)
	if err != nil {
		t.Fatalf("create login history http error: %v", err)
	}
	if respLogin.StatusCode != 200 {
		t.Fatalf("create login history status=%d body=%s", respLogin.StatusCode, string(bodyLogin))
	}
	var lh loginHistoryLog
	if err := testutil.DecodeJSON(bodyLogin, &lh); err != nil {
		t.Fatalf("decode login history: %v body=%s", err, string(bodyLogin))
	}
	if lh.ID == "" || lh.UserID != user.ID || lh.LoginMethod != "password" || !lh.Success {
		t.Fatalf("unexpected login history: %+v body=%s", lh, string(bodyLogin))
	}

	// logout
	respLogout, bodyLogout, err := c.DoJSON("POST", "/activity/login/"+lh.ID+"/logout", map[string]any{}, login.Token)
	if err != nil {
		t.Fatalf("logout http error: %v", err)
	}
	if respLogout.StatusCode != 204 {
		t.Fatalf("expected logout status=204, got %d body=%s", respLogout.StatusCode, string(bodyLogout))
	}

	// query login history
	respList, bodyList, err := c.DoJSON("GET", "/users/"+user.ID+"/activity/login-history?limit=10&offset=0", nil, login.Token)
	if err != nil {
		t.Fatalf("list login history http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list login history status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var history []loginHistoryLog
	if err := testutil.DecodeJSON(bodyList, &history); err != nil {
		t.Fatalf("decode login history list: %v body=%s", err, string(bodyList))
	}
	foundLH := false
	for _, item := range history {
		if item.ID == lh.ID {
			foundLH = true
			break
		}
	}
	if !foundLH {
		t.Fatalf("expected login history id=%s in list, body=%s", lh.ID, string(bodyList))
	}
}
