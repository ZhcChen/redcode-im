package messages_test

import (
	"net/url"
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type reactionSummary struct {
	ReactionKey  string `json:"reaction_key"`
	Count        int    `json:"count"`
	UserIDs      []string `json:"user_ids"`
	HasSelf      bool     `json:"has_self"`
}

type reactionResponse struct {
	Success   bool             `json:"success"`
	Message   string           `json:"message"`
	Summaries []reactionSummary `json:"summaries"`
}

func addReactionHTTP(t *testing.T, c *testutil.Client, token, roomID, messageID, reactionKey string) reactionResponse {
	t.Helper()
	payload := map[string]any{
		"reaction_key": reactionKey,
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/"+messageID+"/reactions", payload, token)
	if err != nil {
		t.Fatalf("add reaction http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("add reaction status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr reactionResponse
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("add reaction decode: %v body=%s", err, string(body))
	}
	if !rr.Success {
		t.Fatalf("add reaction not success: %+v", rr)
	}
	return rr
}

func removeReactionHTTP(t *testing.T, c *testutil.Client, token, roomID, messageID, reactionKey string) reactionResponse {
	t.Helper()
	path := "/rooms/" + roomID + "/messages/" + messageID + "/reactions?reaction_key=" + url.QueryEscape(reactionKey)
	resp, body, err := c.DoJSON("DELETE", path, nil, token)
	if err != nil {
		t.Fatalf("remove reaction http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("remove reaction status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr reactionResponse
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("remove reaction decode: %v body=%s", err, string(body))
	}
	if !rr.Success {
		t.Fatalf("remove reaction not success: %+v", rr)
	}
	return rr
}

func getReactionsHTTP(t *testing.T, c *testutil.Client, token, roomID, messageID string) reactionResponse {
	t.Helper()
	resp, body, err := c.DoJSON("GET", "/rooms/"+roomID+"/messages/"+messageID+"/reactions", nil, token)
	if err != nil {
		t.Fatalf("get reactions http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get reactions status=%d body=%s", resp.StatusCode, string(body))
	}
	var rr reactionResponse
	if err := testutil.DecodeJSON(body, &rr); err != nil {
		t.Fatalf("get reactions decode: %v body=%s", err, string(body))
	}
	if !rr.Success {
		t.Fatalf("get reactions not success: %+v", rr)
	}
	return rr
}

func TestMessageReactions_HTTP_AddGetRemove(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-react-http-"+time.Now().Format("150405"), []string{user2.ID})
	msgID := testutil.SendMessage(t, c, login1.Token, roomID, "react_http_"+time.Now().Format("20060102150405.000000000"))

	const key = "👍"

	addResp := addReactionHTTP(t, c, login2.Token, roomID, msgID, key)
	if !slices.ContainsFunc(addResp.Summaries, func(s reactionSummary) bool {
		return s.ReactionKey == key && s.Count >= 1 && s.HasSelf
	}) {
		t.Fatalf("expected summaries include key=%q has_self=true, got %+v", key, addResp.Summaries)
	}

	getBySender := getReactionsHTTP(t, c, login1.Token, roomID, msgID)
	if !slices.ContainsFunc(getBySender.Summaries, func(s reactionSummary) bool {
		return s.ReactionKey == key && s.Count >= 1 && !s.HasSelf
	}) {
		t.Fatalf("expected sender view has_self=false, got %+v", getBySender.Summaries)
	}

	_ = removeReactionHTTP(t, c, login2.Token, roomID, msgID, key)

	getAfter := getReactionsHTTP(t, c, login2.Token, roomID, msgID)
	if slices.ContainsFunc(getAfter.Summaries, func(s reactionSummary) bool {
		return s.ReactionKey == key && s.Count > 0
	}) {
		t.Fatalf("expected key=%q removed, got %+v", key, getAfter.Summaries)
	}
}
