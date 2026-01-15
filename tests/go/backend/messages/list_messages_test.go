package messages_test

import (
	"net/url"
	"slices"
	"strconv"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type messageInfo struct {
	ID      string `json:"id"`
	RoomID  string `json:"room_id"`
	Content string `json:"content"`
}

func listMessages(t *testing.T, c *testutil.Client, token, roomID string, limit int, beforeID, sinceID string) []messageInfo {
	t.Helper()

	path := "/rooms/" + roomID + "/messages"
	q := url.Values{}
	if limit > 0 {
		q.Set("limit", strconv.Itoa(limit))
	}
	if beforeID != "" {
		q.Set("before_id", beforeID)
	}
	if sinceID != "" {
		q.Set("since_id", sinceID)
	}
	if len(q) > 0 {
		path += "?" + q.Encode()
	}

	resp, body, err := c.DoJSON("GET", path, nil, token)
	if err != nil {
		t.Fatalf("list messages http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list messages status=%d body=%s", resp.StatusCode, string(body))
	}
	var items []messageInfo
	if err := testutil.DecodeJSON(body, &items); err != nil {
		t.Fatalf("list messages decode: %v body=%s", err, string(body))
	}
	return items
}

func TestListMessages_SinceID_ReturnsOnlyNewerMessages(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-since-"+time.Now().Format("150405"), []string{user2.ID})

	needle1 := "since_1_" + time.Now().Format("20060102150405.000000000")
	id1 := testutil.SendMessage(t, c, login1.Token, roomID, needle1)
	time.Sleep(20 * time.Millisecond)

	needle2 := "since_2_" + time.Now().Format("20060102150405.000000000")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, needle2)

	// 用成员 user2 走 since_id 补拉：应只拿到 id1 之后的新消息
	items := listMessages(t, c, login2.Token, roomID, 50, "", id1)
	if !slices.ContainsFunc(items, func(m messageInfo) bool { return m.Content == needle2 }) {
		t.Fatalf("expected to find newer message content=%q, got %v", needle2, items)
	}
	if slices.ContainsFunc(items, func(m messageInfo) bool { return m.Content == needle1 }) {
		t.Fatalf("expected since_id to exclude older message content=%q, got %v", needle1, items)
	}
}
