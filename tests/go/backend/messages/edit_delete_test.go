package messages_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type apiMessageInfo struct {
	ID       string  `json:"id"`
	RoomID   string  `json:"room_id"`
	Content  string  `json:"content"`
	EditedAt *string `json:"edited_at"`
	DeletedAt *string `json:"deleted_at"`
}

func editMessageHTTP(t *testing.T, c *testutil.Client, token, roomID, messageID, newContent string) apiMessageInfo {
	t.Helper()
	payload := map[string]any{
		"content": newContent,
	}
	resp, body, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/messages/"+messageID, payload, token)
	if err != nil {
		t.Fatalf("edit message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("edit message status=%d body=%s", resp.StatusCode, string(body))
	}
	var msg apiMessageInfo
	if err := testutil.DecodeJSON(body, &msg); err != nil {
		t.Fatalf("edit message decode: %v body=%s", err, string(body))
	}
	return msg
}

func deleteMessageHTTP(t *testing.T, c *testutil.Client, token, roomID, messageID string) {
	t.Helper()
	resp, body, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+messageID, nil, token)
	if err != nil {
		t.Fatalf("delete message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("delete message status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestMessages_EditAndDelete_PermissionsAndShape(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-editdel-"+time.Now().Format("150405"), []string{user2.ID})

	orig := "edit_del_orig_" + time.Now().Format("20060102150405.000000000")
	msgID := testutil.SendMessage(t, c, login1.Token, roomID, orig)

	updatedContent := orig + "_edited"
	updated := editMessageHTTP(t, c, login1.Token, roomID, msgID, updatedContent)
	if updated.ID != msgID {
		t.Fatalf("expected edited message id=%s got %s", msgID, updated.ID)
	}
	if updated.Content != updatedContent {
		t.Fatalf("expected edited content=%q got %q", updatedContent, updated.Content)
	}
	if updated.EditedAt == nil || *updated.EditedAt == "" {
		t.Fatalf("expected edited_at set, got %+v", updated)
	}

	// 非发送者编辑应失败（403）
	resp, body, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/messages/"+msgID, map[string]any{"content": "nope"}, login2.Token)
	if err != nil {
		t.Fatalf("edit by non-sender http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for non-sender edit, got %d body=%s", resp.StatusCode, string(body))
	}

	// 删除（发送者）
	deleteMessageHTTP(t, c, login1.Token, roomID, msgID)

	// 非发送者删除应失败（403）
	resp, body, err = c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+msgID, nil, login2.Token)
	if err != nil {
		t.Fatalf("delete by non-sender http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403 for non-sender delete, got %d body=%s", resp.StatusCode, string(body))
	}
}

