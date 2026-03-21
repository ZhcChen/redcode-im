package friends_test

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestFriendRequestAcceptAndEnsureChat_OK(t *testing.T) {
	c := testutil.NewClient()
	password := "pass123456"

	userA := testutil.UniqueUsername("frienda")
	userB := testutil.UniqueUsername("friendb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)

	createReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/friends/requests", loginA.Token, map[string]any{
		"target_user_id": loginB.User.ID,
		"message":        "hi from userA",
	})
	createResp, err := c.HTTP.Do(createReq)
	if err != nil {
		t.Fatalf("create friend request failed: %v", err)
	}
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(createResp.Body)
		t.Fatalf("create friend request expect 200, got %d: %s", createResp.StatusCode, string(body))
	}

	var created struct {
		ID     string `json:"id"`
		Status string `json:"status"`
	}
	if err := json.NewDecoder(createResp.Body).Decode(&created); err != nil {
		t.Fatalf("decode create response failed: %v", err)
	}
	if created.ID == "" {
		t.Fatalf("friend request id is empty")
	}

	listReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/friends/requests?direction=incoming&status=pending", loginB.Token, nil)
	listResp, err := c.HTTP.Do(listReq)
	if err != nil {
		t.Fatalf("list incoming requests failed: %v", err)
	}
	defer listResp.Body.Close()
	if listResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(listResp.Body)
		t.Fatalf("list incoming requests expect 200, got %d: %s", listResp.StatusCode, string(body))
	}

	var incoming []struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(listResp.Body).Decode(&incoming); err != nil {
		t.Fatalf("decode incoming list failed: %v", err)
	}
	foundReq := false
	for _, item := range incoming {
		if item.ID == created.ID {
			foundReq = true
			break
		}
	}
	if !foundReq {
		t.Fatalf("created request not found in incoming list, request_id=%s", created.ID)
	}

	respondReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/friends/requests/"+created.ID+"/respond", loginB.Token, map[string]any{
		"action": "accept",
	})
	respondResp, err := c.HTTP.Do(respondReq)
	if err != nil {
		t.Fatalf("respond request failed: %v", err)
	}
	defer respondResp.Body.Close()
	if respondResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(respondResp.Body)
		t.Fatalf("respond request expect 200, got %d: %s", respondResp.StatusCode, string(body))
	}

	friendsA := listFriends(t, c, loginA.Token)
	assertContainsFriend(t, friendsA, loginB.User.ID)

	friendsB := listFriends(t, c, loginB.Token)
	assertContainsFriend(t, friendsB, loginA.User.ID)

	chatReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/friends/"+loginB.User.ID+"/chat", loginA.Token, nil)
	chatResp, err := c.HTTP.Do(chatReq)
	if err != nil {
		t.Fatalf("ensure private chat failed: %v", err)
	}
	defer chatResp.Body.Close()
	if chatResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(chatResp.Body)
		t.Fatalf("ensure private chat expect 200, got %d: %s", chatResp.StatusCode, string(body))
	}
	var chatResult struct {
		RoomID string `json:"room_id"`
	}
	if err := json.NewDecoder(chatResp.Body).Decode(&chatResult); err != nil {
		t.Fatalf("decode ensure chat response failed: %v", err)
	}
	if chatResult.RoomID == "" {
		t.Fatalf("room_id is empty in ensure chat response")
	}
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func listFriends(t *testing.T, c *testutil.Client, token string) []struct {
	ID   string `json:"id"`
	User struct {
		ID string `json:"id"`
	} `json:"user"`
} {
	t.Helper()
	listReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/friends", token, nil)
	listResp, err := c.HTTP.Do(listReq)
	if err != nil {
		t.Fatalf("list friends failed: %v", err)
	}
	defer listResp.Body.Close()
	if listResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(listResp.Body)
		t.Fatalf("list friends expect 200, got %d: %s", listResp.StatusCode, string(body))
	}
	var result []struct {
		ID   string `json:"id"`
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.NewDecoder(listResp.Body).Decode(&result); err != nil {
		t.Fatalf("decode list friends response failed: %v", err)
	}
	return result
}

func assertContainsFriend(t *testing.T, friends []struct {
	ID   string `json:"id"`
	User struct {
		ID string `json:"id"`
	} `json:"user"`
}, friendUserID string) {
	t.Helper()
	for _, item := range friends {
		if item.User.ID == friendUserID {
			return
		}
	}
	t.Fatalf("friend user not found: %s, friends=%+v", friendUserID, friends)
}
