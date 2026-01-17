package rooms_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type pinRoomResp struct {
	IsPinned bool    `json:"is_pinned"`
	PinnedAt *string `json:"pinned_at"`
}

type notificationSettingsResp struct {
	NotificationSettings int `json:"notification_settings"`
}

func pinRoom(t *testing.T, c *testutil.Client, token, roomID string) pinRoomResp {
	t.Helper()
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/pin", map[string]any{}, token)
	if err != nil {
		t.Fatalf("pin room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("pin room status=%d body=%s", resp.StatusCode, string(body))
	}
	var out pinRoomResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("pin room decode: %v body=%s", err, string(body))
	}
	return out
}

func unpinRoom(t *testing.T, c *testutil.Client, token, roomID string) pinRoomResp {
	t.Helper()
	resp, body, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/pin", nil, token)
	if err != nil {
		t.Fatalf("unpin room http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("unpin room status=%d body=%s", resp.StatusCode, string(body))
	}
	var out pinRoomResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("unpin room decode: %v body=%s", err, string(body))
	}
	return out
}

func updateNotificationSettings(t *testing.T, c *testutil.Client, token, roomID string, setting int) (int, []byte) {
	t.Helper()
	payload := map[string]any{
		"notification_settings": setting,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/notification-settings", payload, token)
	if err != nil {
		t.Fatalf("update notification settings http error: %v", err)
	}
	return resp.StatusCode, body
}

func TestRooms_PinAndNotificationSettings(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-pin-"+time.Now().Format("150405"), []string{member.ID})

	pinned := pinRoom(t, c, memberLogin.Token, roomID)
	if !pinned.IsPinned || pinned.PinnedAt == nil || *pinned.PinnedAt == "" {
		t.Fatalf("expected pinned response, got %+v", pinned)
	}

	unpinned := unpinRoom(t, c, memberLogin.Token, roomID)
	if unpinned.IsPinned || unpinned.PinnedAt != nil {
		t.Fatalf("expected unpinned response, got %+v", unpinned)
	}

	// 通知设置：成功路径
	status, body := updateNotificationSettings(t, c, memberLogin.Token, roomID, 2)
	if status != 200 {
		t.Fatalf("update notification settings status=%d body=%s", status, string(body))
	}
	var out notificationSettingsResp
	if err := testutil.DecodeJSON(body, &out); err != nil {
		t.Fatalf("decode notification settings: %v body=%s", err, string(body))
	}
	if out.NotificationSettings != 2 {
		t.Fatalf("expected notification_settings=2, got %+v", out)
	}

	// 通知设置：非法值
	status2, body2 := updateNotificationSettings(t, c, memberLogin.Token, roomID, 99)
	if status2 == 200 {
		t.Fatalf("expected invalid notification settings to fail, got 200 body=%s", string(body2))
	}
}

