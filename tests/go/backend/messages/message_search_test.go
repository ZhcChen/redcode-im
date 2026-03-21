package messages_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type messageSearchResponse struct {
	Results []struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Content string `json:"content"`
	} `json:"results"`
	Stats struct {
		TotalResults int64  `json:"total_results"`
		Query        string `json:"query"`
	} `json:"stats"`
	HasMore bool `json:"has_more"`
}

func TestMessageSearch_MembershipIsolationAndValidation_OK(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("srcha")
	userB := testutil.UniqueUsername("srchb")
	userC := testutil.UniqueUsername("srchc")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	loginC := registerAndLogin(t, c, userC, password)

	roomAB := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "search-room-ab")
	roomAC := testutil.CreateGroupRoom(t, c, loginA.Token, loginC.User.ID, "search-room-ac")

	keyword := "waveb_keyword_20260305"
	sendTextMessage(t, c, loginA.Token, roomAB.ID, keyword+" first")
	sendTextMessage(t, c, loginA.Token, roomAB.ID, keyword+" second")
	sendTextMessage(t, c, loginA.Token, roomAC.ID, keyword+" hidden")

	queryPath := c.BaseURL + "/messages/search?query=" + url.QueryEscape(keyword) + "&limit=1"
	searchReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, queryPath, loginB.Token, nil)
	searchResp, err := c.HTTP.Do(searchReq)
	if err != nil {
		t.Fatalf("search messages failed: %v", err)
	}
	defer searchResp.Body.Close()
	if searchResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(searchResp.Body)
		t.Fatalf("search messages expect 200, got %d: %s", searchResp.StatusCode, string(body))
	}

	var payload messageSearchResponse
	if err := json.NewDecoder(searchResp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode search response failed: %v", err)
	}
	if payload.Stats.Query != keyword {
		t.Fatalf("search query mismatch: expect %q, got %q", keyword, payload.Stats.Query)
	}
	if payload.Stats.TotalResults != 2 {
		t.Fatalf("search total_results expect 2, got %d", payload.Stats.TotalResults)
	}
	if len(payload.Results) != 1 {
		t.Fatalf("search limit=1 should return 1 result, got %d", len(payload.Results))
	}
	if !payload.HasMore {
		t.Fatalf("search expect has_more=true when total_results > limit")
	}
	for _, item := range payload.Results {
		if item.RoomID != roomAB.ID {
			t.Fatalf("membership isolation failed: unexpected room_id=%s (expect %s)", item.RoomID, roomAB.ID)
		}
		if !strings.Contains(item.Content, keyword) {
			t.Fatalf("search result content mismatch: %q", item.Content)
		}
	}

	emptyReq := testutil.NewAuthedJSONRequest(
		t,
		http.MethodGet,
		c.BaseURL+"/messages/search?query="+url.QueryEscape("   "),
		loginB.Token,
		nil,
	)
	emptyResp, err := c.HTTP.Do(emptyReq)
	if err != nil {
		t.Fatalf("empty query search request failed: %v", err)
	}
	defer emptyResp.Body.Close()
	if emptyResp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(emptyResp.Body)
		t.Fatalf("empty query search expect 400, got %d: %s", emptyResp.StatusCode, string(body))
	}
	var errPayload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(emptyResp.Body).Decode(&errPayload); err != nil {
		t.Fatalf("decode empty query error response failed: %v", err)
	}
	if errPayload.Code != 42201 || !strings.Contains(errPayload.Message, "搜索内容不能为空") {
		t.Fatalf("empty query error payload mismatch: %+v", errPayload)
	}
}
