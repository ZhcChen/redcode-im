package push_test

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type pushLogsResponse struct {
	Logs []struct {
		ID       string         `json:"id"`
		DeviceID string         `json:"deviceId"`
		Event    string         `json:"eventType"`
		Success  bool           `json:"success"`
		Data     map[string]any `json:"data"`
		Error    *string        `json:"error"`
	} `json:"logs"`
	Total int `json:"total"`
}

func TestPushDeviceRegisterSendAndUnregister_OK(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	serviceAccount := buildMockServiceAccountJSON(t, "push-test-project", "http://external-mock:19080/google/oauth2/token")
	configurePushSettings(t, c, admin.Token, serviceAccount)

	password := "pass123456"
	senderName := testutil.UniqueUsername("pusha")
	targetName := testutil.UniqueUsername("pushb")
	sender := registerAndLogin(t, c, senderName, password)
	target := registerAndLogin(t, c, targetName, password)
	room := testutil.CreateGroupRoom(t, c, sender.Token, target.User.ID, "push-room")

	suffix := fmt.Sprintf("%d", time.Now().UnixNano()%1_000_000_000)
	deviceID := "pixel-8-pro-" + suffix
	deviceToken := "fcm-token-" + suffix

	registerReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/push/devices", target.Token, map[string]any{
		"device_id":    deviceID,
		"platform":     "android",
		"channel":      "fcm",
		"device_token": deviceToken,
	})
	registerResp, err := c.HTTP.Do(registerReq)
	if err != nil {
		t.Fatalf("register push device failed: %v", err)
	}
	defer registerResp.Body.Close()
	if registerResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(registerResp.Body)
		t.Fatalf("register push device expect 200, got %d: %s", registerResp.StatusCode, string(body))
	}
	var registerPayload struct {
		Success  bool   `json:"success"`
		DeviceID string `json:"device_id"`
	}
	if err := json.NewDecoder(registerResp.Body).Decode(&registerPayload); err != nil {
		t.Fatalf("decode register push device response failed: %v", err)
	}
	if !registerPayload.Success || registerPayload.DeviceID != deviceID {
		t.Fatalf("invalid register push device response: %+v", registerPayload)
	}

	sendReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages", sender.Token, map[string]any{
		"content": "push message " + suffix,
	})
	sendResp, err := c.HTTP.Do(sendReq)
	if err != nil {
		t.Fatalf("send room message failed: %v", err)
	}
	defer sendResp.Body.Close()
	if sendResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sendResp.Body)
		t.Fatalf("send room message expect 200, got %d: %s", sendResp.StatusCode, string(body))
	}

	log, ok := waitPushLogForDevice(t, c, admin.Token, deviceID, 45*time.Second)
	if !ok {
		t.Fatalf("push log not found for device=%s within timeout", deviceID)
	}
	if !log.Success {
		msg := ""
		if log.Error != nil {
			msg = *log.Error
		}
		t.Fatalf("push log indicates send failure for device=%s, error=%s", deviceID, msg)
	}
	if log.Event != "message" {
		t.Fatalf("push log event should be message, got %s", log.Event)
	}
	if eventType, _ := log.Data["type"].(string); eventType != "message" {
		t.Fatalf("push log data.type should be message, got %+v", log.Data)
	}

	unregisterReq := testutil.NewAuthedJSONRequest(t, http.MethodDelete, c.BaseURL+"/push/devices/"+url.PathEscape(deviceID), target.Token, nil)
	unregisterResp, err := c.HTTP.Do(unregisterReq)
	if err != nil {
		t.Fatalf("unregister push device failed: %v", err)
	}
	defer unregisterResp.Body.Close()
	if unregisterResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(unregisterResp.Body)
		t.Fatalf("unregister push device expect 200, got %d: %s", unregisterResp.StatusCode, string(body))
	}
	var unregisterPayload struct {
		Success bool   `json:"success"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(unregisterResp.Body).Decode(&unregisterPayload); err != nil {
		t.Fatalf("decode unregister push device response failed: %v", err)
	}
	if !unregisterPayload.Success || !strings.Contains(unregisterPayload.Message, "设备已注销") {
		t.Fatalf("unexpected unregister push device response: %+v", unregisterPayload)
	}
}

func configurePushSettings(t *testing.T, c *testutil.Client, adminToken, serviceAccountJSON string) {
	t.Helper()

	settingsReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPut, c.BaseURL+"/api/admin/settings/push", adminToken, map[string]any{
		"enabled":        true,
		"skip_if_online": false,
	})
	settingsResp, err := c.HTTP.Do(settingsReq)
	if err != nil {
		t.Fatalf("update push settings failed: %v", err)
	}
	defer settingsResp.Body.Close()
	if settingsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(settingsResp.Body)
		t.Fatalf("update push settings expect 200, got %d: %s", settingsResp.StatusCode, string(body))
	}

	providerReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPut, c.BaseURL+"/api/admin/settings/push/providers/fcm", adminToken, map[string]any{
		"enabled":              true,
		"service_account_json": serviceAccountJSON,
	})
	providerResp, err := c.HTTP.Do(providerReq)
	if err != nil {
		t.Fatalf("upsert push provider failed: %v", err)
	}
	defer providerResp.Body.Close()
	if providerResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(providerResp.Body)
		t.Fatalf("upsert push provider expect 200, got %d: %s", providerResp.StatusCode, string(body))
	}
	var providerPayload struct {
		Enabled   bool `json:"enabled"`
		HasSecret bool `json:"has_secret"`
	}
	if err := json.NewDecoder(providerResp.Body).Decode(&providerPayload); err != nil {
		t.Fatalf("decode upsert push provider response failed: %v", err)
	}
	if !providerPayload.Enabled || !providerPayload.HasSecret {
		t.Fatalf("push provider should be enabled with secret: %+v", providerPayload)
	}
}

func waitPushLogForDevice(t *testing.T, c *testutil.Client, adminToken, deviceID string, timeout time.Duration) (log struct {
	ID       string
	DeviceID string
	Event    string
	Success  bool
	Data     map[string]any
	Error    *string
}, ok bool) {
	t.Helper()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		listReq := testutil.NewAuthedJSONRequestWithToken(http.MethodGet, c.BaseURL+"/api/admin/push/logs?deviceId="+url.QueryEscape(deviceID)+"&eventType=message&limit=20", adminToken, nil)
		listResp, err := c.HTTP.Do(listReq)
		if err != nil {
			t.Fatalf("list push logs failed: %v", err)
		}

		var payload pushLogsResponse
		if listResp.StatusCode == http.StatusOK {
			if err := json.NewDecoder(listResp.Body).Decode(&payload); err != nil {
				listResp.Body.Close()
				t.Fatalf("decode push logs response failed: %v", err)
			}
		} else {
			body, _ := io.ReadAll(listResp.Body)
			listResp.Body.Close()
			t.Fatalf("list push logs expect 200, got %d: %s", listResp.StatusCode, string(body))
		}
		listResp.Body.Close()

		for _, item := range payload.Logs {
			if item.DeviceID != deviceID {
				continue
			}
			log = struct {
				ID       string
				DeviceID string
				Event    string
				Success  bool
				Data     map[string]any
				Error    *string
			}{
				ID:       item.ID,
				DeviceID: item.DeviceID,
				Event:    item.Event,
				Success:  item.Success,
				Data:     item.Data,
				Error:    item.Error,
			}
			return log, true
		}

		time.Sleep(2 * time.Second)
	}

	return log, false
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func buildMockServiceAccountJSON(t *testing.T, projectID, tokenURI string) string {
	t.Helper()

	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate rsa key for service account failed: %v", err)
	}

	pemBytes := pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
	})

	payload := map[string]any{
		"project_id":   projectID,
		"client_email": "push-test@redcode-im.iam.gserviceaccount.com",
		"private_key":  string(pemBytes),
		"token_uri":    tokenURI,
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal mock service account failed: %v", err)
	}
	return string(raw)
}
