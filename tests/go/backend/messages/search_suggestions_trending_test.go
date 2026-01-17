package messages_test

import (
	"net/url"
	"slices"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type trendingKeyword struct {
	Keyword   string `json:"keyword"`
	Frequency int64  `json:"frequency"`
}

func TestMessageSearch_SuggestionsAndTrending(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-suggest-"+time.Now().Format("150405"), []string{user2.ID})

	// 造一些可预测的词汇
	_ = testutil.SendMessage(t, c, login1.Token, roomID, "hello world")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, "hello there")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, "trend trend")
	_ = testutil.SendMessage(t, c, login1.Token, roomID, "trend other")

	// prefix 长度 < 2：返回空列表
	resp0, body0, err := c.DoJSON("GET", "/messages/search/suggestions?prefix=h", nil, login2.Token)
	if err != nil {
		t.Fatalf("suggestions(short) http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("suggestions(short) status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var empty []string
	if err := testutil.DecodeJSON(body0, &empty); err != nil {
		t.Fatalf("decode suggestions(short): %v body=%s", err, string(body0))
	}
	if len(empty) != 0 {
		t.Fatalf("expected empty suggestions for short prefix, got %v", empty)
	}

	resp1, body1, err := c.DoJSON("GET", "/messages/search/suggestions?prefix="+url.QueryEscape("he"), nil, login2.Token)
	if err != nil {
		t.Fatalf("suggestions http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("suggestions status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var suggestions []string
	if err := testutil.DecodeJSON(body1, &suggestions); err != nil {
		t.Fatalf("decode suggestions: %v body=%s", err, string(body1))
	}
	if len(suggestions) == 0 {
		t.Fatalf("expected suggestions non-empty, got empty")
	}
	if !slices.ContainsFunc(suggestions, func(s string) bool { return strings.HasPrefix(strings.ToLower(s), "he") }) {
		t.Fatalf("expected suggestions contain prefix 'he', got %v", suggestions)
	}

	resp2, body2, err := c.DoJSON("GET", "/messages/search/trending", nil, login2.Token)
	if err != nil {
		t.Fatalf("trending http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("trending status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var keywords []trendingKeyword
	if err := testutil.DecodeJSON(body2, &keywords); err != nil {
		t.Fatalf("decode trending: %v body=%s", err, string(body2))
	}
	if !slices.ContainsFunc(keywords, func(k trendingKeyword) bool { return k.Keyword == "trend" && k.Frequency >= 3 }) {
		t.Fatalf("expected trending contains keyword 'trend' frequency>=3, got %v", keywords)
	}
}

