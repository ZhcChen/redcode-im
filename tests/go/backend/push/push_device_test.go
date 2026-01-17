package push_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type registerResp struct {
	Success  bool   `json:"success"`
	Message  string `json:"message"`
	DeviceID string `json:"device_id"`
}

type unregisterResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestPush_RegisterAndUnregisterDevice(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	deviceID := "go-dev-" + time.Now().Format("150405.000000000")
	deviceToken := "token-" + deviceID

	resp, body, err := c.DoJSON("POST", "/push/devices", map[string]any{
		"device_id":    deviceID,
		"platform":     "ios",
		"channel":      "apns",
		"device_token": deviceToken,
	}, login.Token)
	if err != nil {
		t.Fatalf("register device http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("register device status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr registerResp
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("register device decode: %v body=%s", err, string(body))
	}
	if !rr.Success || rr.DeviceID != deviceID {
		t.Fatalf("unexpected register resp: %+v body=%s", rr, string(body))
	}

	resp2, body2, err := c.DoJSON("DELETE", "/push/devices/"+deviceID, nil, login.Token)
	if err != nil {
		t.Fatalf("unregister device http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("unregister device status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var ur unregisterResp
	if err := testutil.DecodeJSON(body2, &ur); err != nil {
		t.Fatalf("unregister device decode: %v body=%s", err, string(body2))
	}
	if !ur.Success {
		t.Fatalf("expected unregister success=true, got false body=%s", string(body2))
	}

	// 再注销一次应保持 200 且提示“已注销/不存在”（不强依赖文案）
	resp3, body3, err := c.DoJSON("DELETE", "/push/devices/"+deviceID, nil, login.Token)
	if err != nil {
		t.Fatalf("unregister device (second) http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("unregister device (second) status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var ur2 unregisterResp
	if err := testutil.DecodeJSON(body3, &ur2); err != nil {
		t.Fatalf("unregister device (second) decode: %v body=%s", err, string(body3))
	}
	if !ur2.Success {
		t.Fatalf("expected second unregister success=true, got false body=%s", string(body3))
	}
}

func TestPush_RegisterDevice_Validations(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	resp, body, err := c.DoJSON("POST", "/push/devices", map[string]any{
		"device_id":    "",
		"platform":     "ios",
		"channel":      "apns",
		"device_token": "x",
	}, login.Token)
	if err != nil {
		t.Fatalf("register device (invalid) http error: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("expected invalid device_id status=400, got %d body=%s", resp.StatusCode, string(body))
	}
}

