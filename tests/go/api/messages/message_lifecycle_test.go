package messages_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestMessageSendEditDeleteAndList_OK(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueEmail("msga")
	userB := testutil.UniqueEmail("msgb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)

	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "msg-room")

	sendReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages", loginA.Token, map[string]any{
		"content": "hello from integration test",
	})
	sendResp, err := c.HTTP.Do(sendReq)
	if err != nil {
		t.Fatalf("send message failed: %v", err)
	}
	defer sendResp.Body.Close()
	if sendResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sendResp.Body)
		t.Fatalf("send message expect 200, got %d: %s", sendResp.StatusCode, string(body))
	}

	var sendResult struct {
		Message struct {
			ID      string `json:"id"`
			Content string `json:"content"`
		} `json:"message"`
	}
	if err := json.NewDecoder(sendResp.Body).Decode(&sendResult); err != nil {
		t.Fatalf("decode send response failed: %v", err)
	}
	if sendResult.Message.ID == "" {
		t.Fatalf("message id is empty")
	}

	editReq := testutil.NewAuthedJSONRequest(t, http.MethodPatch, c.BaseURL+"/rooms/"+room.ID+"/messages/"+sendResult.Message.ID, loginA.Token, map[string]any{
		"content": "edited message",
	})
	editResp, err := c.HTTP.Do(editReq)
	if err != nil {
		t.Fatalf("edit message failed: %v", err)
	}
	defer editResp.Body.Close()
	if editResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(editResp.Body)
		t.Fatalf("edit message expect 200, got %d: %s", editResp.StatusCode, string(body))
	}

	listReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/rooms/"+room.ID+"/messages?limit=20", loginA.Token, nil)
	listResp, err := c.HTTP.Do(listReq)
	if err != nil {
		t.Fatalf("list messages failed: %v", err)
	}
	defer listResp.Body.Close()
	if listResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(listResp.Body)
		t.Fatalf("list messages expect 200, got %d: %s", listResp.StatusCode, string(body))
	}

	var messages []struct {
		ID      string `json:"id"`
		Content string `json:"content"`
	}
	if err := json.NewDecoder(listResp.Body).Decode(&messages); err != nil {
		t.Fatalf("decode list messages failed: %v", err)
	}
	foundEdited := false
	for _, m := range messages {
		if m.ID == sendResult.Message.ID && m.Content == "edited message" {
			foundEdited = true
			break
		}
	}
	if !foundEdited {
		t.Fatalf("edited message not found in list")
	}

	delReq := testutil.NewAuthedJSONRequest(t, http.MethodDelete, c.BaseURL+"/rooms/"+room.ID+"/messages/"+sendResult.Message.ID, loginA.Token, nil)
	delResp, err := c.HTTP.Do(delReq)
	if err != nil {
		t.Fatalf("delete message failed: %v", err)
	}
	defer delResp.Body.Close()
	if delResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(delResp.Body)
		t.Fatalf("delete message expect 200, got %d: %s", delResp.StatusCode, string(body))
	}
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}
