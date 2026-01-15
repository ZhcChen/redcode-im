package messages_test

import (
	"net/url"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type searchResponse struct {
	Results []struct {
		ID       string `json:"id"`
		RoomID   string `json:"room_id"`
		Content  string `json:"content"`
		RoomName string `json:"room_name"`
	} `json:"results"`
	Stats struct {
		TotalResults int64  `json:"total_results"`
		SearchTimeMs int64  `json:"search_time_ms"`
		Query        string `json:"query"`
	} `json:"stats"`
	HasMore bool `json:"has_more"`
}

func searchMessages(t *testing.T, c *testutil.Client, token, query, roomID string) searchResponse {
	t.Helper()
	path := "/messages/search?query=" + url.QueryEscape(query)
	if roomID != "" {
		path += "&room_id=" + url.QueryEscape(roomID)
	}
	resp, body, err := c.DoJSON("GET", path, nil, token)
	if err != nil {
		t.Fatalf("search messages http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("search messages status=%d body=%s", resp.StatusCode, string(body))
	}
	var sr searchResponse
	if err := testutil.DecodeJSON(body, &sr); err != nil {
		t.Fatalf("search messages decode: %v body=%s", err, string(body))
	}
	return sr
}

func TestMessageSearch_OnlyReturnsAccessibleRooms(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	sharedRoomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-search-shared-"+time.Now().Format("150405"), []string{user2.ID})
	privateRoomID := testutil.CreatePublicRoom(t, c, login1.Token, "go-search-private-"+time.Now().Format("150405"))

	needle := "needle_" + time.Now().Format("20060102150405.000000000")
	sharedContent := "shared " + needle
	privateContent := "private " + needle

	_ = testutil.SendMessage(t, c, login1.Token, sharedRoomID, sharedContent)
	_ = testutil.SendMessage(t, c, login1.Token, privateRoomID, privateContent)

	// user2 只能搜索到自己可见房间内的消息
	res := searchMessages(t, c, login2.Token, needle, "")
	if res.Stats.TotalResults != 1 || len(res.Results) != 1 {
		t.Fatalf("expected 1 result, got total=%d len=%d", res.Stats.TotalResults, len(res.Results))
	}
	if !strings.Contains(res.Results[0].Content, "shared") {
		t.Fatalf("unexpected content: %q", res.Results[0].Content)
	}

	// 指定 user2 不在的房间，必须返回空结果（不能越权）
	res2 := searchMessages(t, c, login2.Token, needle, privateRoomID)
	if res2.Stats.TotalResults != 0 || len(res2.Results) != 0 {
		t.Fatalf("expected 0 result for private room, got total=%d len=%d", res2.Stats.TotalResults, len(res2.Results))
	}
}
