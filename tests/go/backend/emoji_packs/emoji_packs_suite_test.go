package emoji_packs_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type suiteAddResponse struct {
	Success bool `json:"success"`
	Count   int  `json:"count"`
}

type suitePackWithItems struct {
	Pack struct {
		ID       string  `json:"id"`
		Name     string  `json:"name"`
		PackType int     `json:"pack_type"`
		ParentID *string `json:"parent_id"`
	} `json:"pack"`
	Items []struct {
		ID     string `json:"id"`
		PackID string `json:"pack_id"`
	} `json:"items"`
}

func TestEmojiPacks_SuiteAddAndListPacks(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip emoji suites test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	suiteName := "go-emoji-suite-" + time.Now().Format("150405.000000000")
	respSuite, bodySuite, err := c.DoJSON("POST", "/api/admin/emoji-packs", map[string]any{
		"name":        suiteName,
		"description": "go-test-suite",
		"is_active":   true,
		"pack_type":   1,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create emoji suite http error: %v", err)
	}
	if respSuite.StatusCode != 200 {
		t.Fatalf("create emoji suite status=%d body=%s", respSuite.StatusCode, string(bodySuite))
	}
	var suite emojiPackResponse
	if err := testutil.DecodeJSON(bodySuite, &suite); err != nil {
		t.Fatalf("decode created emoji suite: %v body=%s", err, string(bodySuite))
	}
	if suite.ID == "" || suite.Name != suiteName {
		t.Fatalf("unexpected suite: %+v body=%s", suite, string(bodySuite))
	}

	childName := "go-emoji-pack-" + time.Now().Format("150405.000000000")
	respChild, bodyChild, err := c.DoJSON("POST", "/api/admin/emoji-packs", map[string]any{
		"name":        childName,
		"description": "go-test-child",
		"is_active":   true,
		"pack_type":   0,
		"parent_id":   suite.ID,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create child pack http error: %v", err)
	}
	if respChild.StatusCode != 200 {
		t.Fatalf("create child pack status=%d body=%s", respChild.StatusCode, string(bodyChild))
	}
	var child emojiPackResponse
	if err := testutil.DecodeJSON(bodyChild, &child); err != nil {
		t.Fatalf("decode child pack: %v body=%s", err, string(bodyChild))
	}
	if child.ID == "" || child.ParentID == nil || *child.ParentID != suite.ID {
		t.Fatalf("unexpected child pack: %+v body=%s", child, string(bodyChild))
	}

	respItem, bodyItem, err := c.DoJSON("POST", "/api/admin/emoji-items", map[string]any{
		"pack_id":   child.ID,
		"name":      "go-emoji-item",
		"image_url": "https://example.com/emoji.png",
	}, admin.Token)
	if err != nil {
		t.Fatalf("create emoji item http error: %v", err)
	}
	if respItem.StatusCode != 200 {
		t.Fatalf("create emoji item status=%d body=%s", respItem.StatusCode, string(bodyItem))
	}

	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	respAdd, bodyAdd, err := c.DoJSON("POST", "/emoji-packs/suites/"+suite.ID+"/add", map[string]any{}, login.Token)
	if err != nil {
		t.Fatalf("add suite packs http error: %v", err)
	}
	if respAdd.StatusCode != 200 {
		t.Fatalf("add suite packs status=%d body=%s", respAdd.StatusCode, string(bodyAdd))
	}
	var addRes suiteAddResponse
	if err := testutil.DecodeJSON(bodyAdd, &addRes); err != nil {
		t.Fatalf("decode suite add response: %v body=%s", err, string(bodyAdd))
	}
	if !addRes.Success || addRes.Count < 1 {
		t.Fatalf("expected suite add success/count, got %+v body=%s", addRes, string(bodyAdd))
	}

	respList, bodyList, err := c.DoJSON("GET", "/emoji-packs/suites/"+suite.ID+"/packs", nil, login.Token)
	if err != nil {
		t.Fatalf("list suite packs http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list suite packs status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var packs []suitePackWithItems
	if err := testutil.DecodeJSON(bodyList, &packs); err != nil {
		t.Fatalf("decode suite packs: %v body=%s", err, string(bodyList))
	}
	foundChild := false
	for _, p := range packs {
		if p.Pack.ID == child.ID {
			foundChild = true
			if len(p.Items) == 0 {
				t.Fatalf("expected child pack items non-empty, pack=%+v body=%s", p.Pack, string(bodyList))
			}
			break
		}
	}
	if !foundChild {
		t.Fatalf("expected child pack id=%s in suite packs, body=%s", child.ID, string(bodyList))
	}
}
