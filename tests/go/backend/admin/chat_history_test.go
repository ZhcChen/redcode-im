package admin_test

import (
	"net/url"
	"os"
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type chatHistoryResp struct {
	Messages []struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Content string `json:"content"`
	} `json:"messages"`
	Total    int64 `json:"total"`
	Page     int64 `json:"page"`
	PageSize int64 `json:"page_size"`
}

type userRoomsResp struct {
	Rooms []struct {
		ID          string `json:"id"`
		MemberCount int64  `json:"member_count"`
		LastMessage *struct {
			Content string `json:"content"`
		} `json:"last_message"`
	} `json:"rooms"`
	Total int64 `json:"total"`
}

func TestAdmin_ChatHistory_QueryByKeywordAndRoom(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin chat history test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-admin-ch-"+time.Now().Format("150405"), []string{user2.ID})

	needle := "admin_chat_history_" + time.Now().Format("20060102150405.000000000")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, needle)

	// 全局聊天记录按 keyword 查询
	path := "/api/admin/chat-history?page=1&page_size=20&keyword=" + url.QueryEscape(needle)
	resp1, body1, err := c.DoJSON("GET", path, nil, admin.Token)
	if err != nil {
		t.Fatalf("admin chat-history http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("admin chat-history status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var out1 chatHistoryResp
	if err := testutil.DecodeJSON(body1, &out1); err != nil {
		t.Fatalf("decode chat-history: %v body=%s", err, string(body1))
	}
	if out1.Total <= 0 || len(out1.Messages) == 0 {
		t.Fatalf("expected messages non-empty, got %+v body=%s", out1, string(body1))
	}
	if !slices.ContainsFunc(out1.Messages, func(m struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Content string `json:"content"`
	}) bool { return m.RoomID == roomID && m.Content == needle }) {
		t.Fatalf("expected message in result, got %+v", out1.Messages)
	}

	// 查询用户参与房间
	resp2, body2, err := c.DoJSON("GET", "/api/admin/users/"+user1.ID+"/rooms", nil, admin.Token)
	if err != nil {
		t.Fatalf("admin user rooms http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("admin user rooms status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var out2 userRoomsResp
	if err := testutil.DecodeJSON(body2, &out2); err != nil {
		t.Fatalf("decode user rooms: %v body=%s", err, string(body2))
	}
	if out2.Total <= 0 || len(out2.Rooms) == 0 {
		t.Fatalf("expected rooms non-empty, got %+v body=%s", out2, string(body2))
	}
	if !slices.ContainsFunc(out2.Rooms, func(r struct {
		ID          string `json:"id"`
		MemberCount int64  `json:"member_count"`
		LastMessage *struct {
			Content string `json:"content"`
		} `json:"last_message"`
	}) bool { return r.ID == roomID }) {
		t.Fatalf("expected room in user rooms, got %+v", out2.Rooms)
	}

	// 房间维度聊天记录
	path3 := "/api/admin/rooms/" + roomID + "/chat-history?page=1&page_size=20&keyword=" + url.QueryEscape(needle)
	resp3, body3, err := c.DoJSON("GET", path3, nil, admin.Token)
	if err != nil {
		t.Fatalf("admin room chat-history http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("admin room chat-history status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var out3 chatHistoryResp
	if err := testutil.DecodeJSON(body3, &out3); err != nil {
		t.Fatalf("decode room chat-history: %v body=%s", err, string(body3))
	}
	if out3.Total <= 0 || len(out3.Messages) == 0 {
		t.Fatalf("expected room messages non-empty, got %+v body=%s", out3, string(body3))
	}
	if !slices.ContainsFunc(out3.Messages, func(m struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Content string `json:"content"`
	}) bool { return m.RoomID == roomID && m.Content == needle }) {
		t.Fatalf("expected message in room result, got %+v", out3.Messages)
	}
}

