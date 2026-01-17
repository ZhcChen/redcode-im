package messages_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type pinMessageResp struct {
	RoomID   string  `json:"room_id"`
	IsPinned bool    `json:"is_pinned"`
	PinnedAt *string `json:"pinned_at"`
	PinnedBy *string `json:"pinned_by"`
}

type clearRoomMessagesResp struct {
	RoomID       string `json:"room_id"`
	DeletedCount int64  `json:"deleted_count"`
}

type readUntilResp struct {
	Success bool  `json:"success"`
	Count   int64 `json:"count"`
}

type sendMessageEnvelope struct {
	Message struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Content string `json:"content"`
	} `json:"message"`
}

func TestMessages_PinAndUnpin_HTTP(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-pin-"+time.Now().Format("150405"), []string{member.ID})
	msgID := testutil.SendMessage(t, c, ownerLogin.Token, roomID, "pin_"+time.Now().Format("20060102150405.000000000"))

	// 任意成员均可置顶
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/"+msgID+"/pin", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("pin message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("pin message status=%d body=%s", resp.StatusCode, string(body))
	}
	var pr pinMessageResp
	if err := testutil.DecodeJSON(body, &pr); err != nil {
		t.Fatalf("pin message decode: %v body=%s", err, string(body))
	}
	if !pr.IsPinned || pr.RoomID != roomID || pr.PinnedAt == nil || pr.PinnedBy == nil {
		t.Fatalf("unexpected pin response: %+v body=%s", pr, string(body))
	}

	resp2, body2, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+msgID+"/pin", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("unpin message http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("unpin message status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var ur pinMessageResp
	if err := testutil.DecodeJSON(body2, &ur); err != nil {
		t.Fatalf("unpin message decode: %v body=%s", err, string(body2))
	}
	if ur.IsPinned {
		t.Fatalf("expected is_pinned=false after unpin, got %+v body=%s", ur, string(body2))
	}

	// 幂等：重复取消也应稳定返回 200
	resp3, body3, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages/"+msgID+"/pin", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("unpin message (second) http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("unpin message (second) status=%d body=%s", resp3.StatusCode, string(body3))
	}
}

func TestMessages_ClearRoomMessages_GroupOwnerOnly(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-clear-"+time.Now().Format("150405"), []string{member.ID})
	_ = testutil.SendMessage(t, c, ownerLogin.Token, roomID, "clear_1_"+time.Now().Format("20060102150405.000000000"))
	_ = testutil.SendMessage(t, c, ownerLogin.Token, roomID, "clear_2_"+time.Now().Format("20060102150405.000000000"))

	// 普通成员不允许清空
	resp0, body0, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages", nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("member clear messages http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected member clear status=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	resp1, body1, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/messages", nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner clear messages http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("owner clear messages status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var cr clearRoomMessagesResp
	if err := testutil.DecodeJSON(body1, &cr); err != nil {
		t.Fatalf("decode clear messages resp: %v body=%s", err, string(body1))
	}
	if cr.RoomID != roomID || cr.DeletedCount < 2 {
		t.Fatalf("unexpected clear messages resp: %+v", cr)
	}

	// 列表应为空
	itemsOwner := listMessages(t, c, ownerLogin.Token, roomID, 50, "", "")
	if len(itemsOwner) != 0 {
		t.Fatalf("expected no messages after clear, got %v", itemsOwner)
	}
	itemsMember := listMessages(t, c, memberLogin.Token, roomID, 50, "", "")
	if len(itemsMember) != 0 {
		t.Fatalf("expected no messages after clear (member), got %v", itemsMember)
	}
}

func TestMessages_ReadUntil_MarksMultipleMessages(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-readuntil-"+time.Now().Format("150405"), []string{user2.ID})

	_ = testutil.SendMessage(t, c, login1.Token, roomID, "ru_1_"+time.Now().Format("20060102150405.000000000"))
	_ = testutil.SendMessage(t, c, login1.Token, roomID, "ru_2_"+time.Now().Format("20060102150405.000000000"))
	lastID := testutil.SendMessage(t, c, login1.Token, roomID, "ru_3_"+time.Now().Format("20060102150405.000000000"))

	before := getUnreadCount(t, c, login2.Token, roomID)
	if before.UnreadCount < 3 {
		t.Fatalf("expected unread_count>=3 before read_until, got %+v", before)
	}

	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/read_until", map[string]any{"message_id": lastID}, login2.Token)
	if err != nil {
		t.Fatalf("read_until http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("read_until status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr readUntilResp
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("read_until decode: %v body=%s", err, string(body))
	}
	if !rr.Success || rr.Count <= 0 {
		t.Fatalf("unexpected read_until resp: %+v body=%s", rr, string(body))
	}

	after := getUnreadCount(t, c, login2.Token, roomID)
	if after.UnreadCount != 0 {
		t.Fatalf("expected unread_count=0 after read_until, got %+v", after)
	}
	if after.LastReadMessageID == nil || *after.LastReadMessageID != lastID {
		t.Fatalf("expected last_read_message_id=%s, got %+v", lastID, after)
	}
}

func TestMessages_Forward_TextMessage(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	_ = testutil.Login(t, c, user2.Username, pass)

	sourceRoom := testutil.CreateGroupRoom(t, c, login1.Token, "go-fwd-src-"+time.Now().Format("150405"), []string{user2.ID})
	targetRoom := testutil.CreateGroupRoom(t, c, login1.Token, "go-fwd-dst-"+time.Now().Format("150405"), []string{user2.ID})

	origContent := "fwd_" + time.Now().Format("20060102150405.000000000")
	origID := testutil.SendMessage(t, c, login1.Token, sourceRoom, origContent)

	resp, body, err := c.DoJSON("POST", "/rooms/"+targetRoom+"/messages/forward", map[string]any{
		"original_message_id": origID,
	}, login1.Token)
	if err != nil {
		t.Fatalf("forward message http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("forward message status=%d body=%s", resp.StatusCode, string(body))
	}
	var sm sendMessageEnvelope
	if err := testutil.DecodeJSON(body, &sm); err != nil {
		t.Fatalf("forward message decode: %v body=%s", err, string(body))
	}
	if sm.Message.ID == "" || sm.Message.RoomID != targetRoom || sm.Message.Content != origContent {
		t.Fatalf("unexpected forward response: %+v body=%s", sm, string(body))
	}

	items := listMessages(t, c, login1.Token, targetRoom, 100, "", "")
	if !slices.ContainsFunc(items, func(m messageInfo) bool { return m.Content == origContent }) {
		t.Fatalf("expected forwarded content in target room, got %v", items)
	}
}

