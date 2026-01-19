package emoji_packs_test

import (
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type emojiPackResponse struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	IsActive bool    `json:"is_active"`
	PackType int     `json:"pack_type"`
	ParentID *string `json:"parent_id"`
}

type userPacksResponseItem struct {
	Pack struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"pack"`
	Items []any `json:"items"`
}

type simpleSuccessResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type emojiDownloadURLResponse struct {
	Success     bool   `json:"success"`
	Message     string `json:"message"`
	DownloadURL string `json:"download_url"`
}

func TestEmojiPacks_UserFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip emoji packs test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// 生成 download-url 需要默认存储提供商（仅用于签名/URL 拼装，不依赖外网）
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	name := "go-emoji-pack-" + time.Now().Format("150405.000000000")
	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/emoji-packs", map[string]any{
		"name":        name,
		"description": "go-test",
		"is_active":   true,
		"pack_type":   0,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create emoji pack http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create emoji pack status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created emojiPackResponse
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode created emoji pack: %v body=%s", err, string(bodyCreate))
	}
	if created.ID == "" || created.Name != name {
		t.Fatalf("unexpected created pack: %+v body=%s", created, string(bodyCreate))
	}

	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	// available packs should include created pack
	respAvail, bodyAvail, err := c.DoJSON("GET", "/emoji-packs/available", nil, login.Token)
	if err != nil {
		t.Fatalf("list available packs http error: %v", err)
	}
	if respAvail.StatusCode != 200 {
		t.Fatalf("list available packs status=%d body=%s", respAvail.StatusCode, string(bodyAvail))
	}
	var available []emojiPackResponse
	if err := testutil.DecodeJSON(bodyAvail, &available); err != nil {
		t.Fatalf("decode available packs: %v body=%s", err, string(bodyAvail))
	}
	found := false
	for _, p := range available {
		if p.ID == created.ID {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected pack id=%s in available list, body=%s", created.ID, string(bodyAvail))
	}

	// add pack
	respAdd, bodyAdd, err := c.DoJSON("POST", "/emoji-packs/"+created.ID+"/add", map[string]any{}, login.Token)
	if err != nil {
		t.Fatalf("add user pack http error: %v", err)
	}
	if respAdd.StatusCode != 200 {
		t.Fatalf("add user pack status=%d body=%s", respAdd.StatusCode, string(bodyAdd))
	}
	var addRes simpleSuccessResponse
	if err := testutil.DecodeJSON(bodyAdd, &addRes); err != nil {
		t.Fatalf("decode add user pack: %v body=%s", err, string(bodyAdd))
	}
	if !addRes.Success {
		t.Fatalf("expected add success=true, body=%s", string(bodyAdd))
	}

	// list my packs should include it
	respMy, bodyMy, err := c.DoJSON("GET", "/emoji-packs/my", nil, login.Token)
	if err != nil {
		t.Fatalf("list my packs http error: %v", err)
	}
	if respMy.StatusCode != 200 {
		t.Fatalf("list my packs status=%d body=%s", respMy.StatusCode, string(bodyMy))
	}
	var my []userPacksResponseItem
	if err := testutil.DecodeJSON(bodyMy, &my); err != nil {
		t.Fatalf("decode my packs: %v body=%s", err, string(bodyMy))
	}
	foundMy := false
	for _, p := range my {
		if p.Pack.ID == created.ID {
			foundMy = true
			break
		}
	}
	if !foundMy {
		t.Fatalf("expected pack id=%s in my packs, body=%s", created.ID, string(bodyMy))
	}

	// search
	respSearch, bodySearch, err := c.DoJSON("GET", "/emoji-packs/search?keyword="+name, nil, login.Token)
	if err != nil {
		t.Fatalf("search packs http error: %v", err)
	}
	if respSearch.StatusCode != 200 {
		t.Fatalf("search packs status=%d body=%s", respSearch.StatusCode, string(bodySearch))
	}

	// download url (only validates key prefix, does not require object exist)
	respDL, bodyDL, err := c.DoJSON("GET", "/emoji-packs/download-url?object_key=emoji-packs/icons/test.png", nil, login.Token)
	if err != nil {
		t.Fatalf("emoji download url http error: %v", err)
	}
	if respDL.StatusCode != 200 {
		t.Fatalf("emoji download url status=%d body=%s", respDL.StatusCode, string(bodyDL))
	}
	var dl emojiDownloadURLResponse
	if err := testutil.DecodeJSON(bodyDL, &dl); err != nil {
		t.Fatalf("decode emoji download url: %v body=%s", err, string(bodyDL))
	}
	if !dl.Success || dl.DownloadURL == "" {
		t.Fatalf("expected download_url non-empty, body=%s", string(bodyDL))
	}

	// remove pack
	respRemove, bodyRemove, err := c.DoJSON("DELETE", "/emoji-packs/"+created.ID+"/remove", nil, login.Token)
	if err != nil {
		t.Fatalf("remove user pack http error: %v", err)
	}
	if respRemove.StatusCode != 200 {
		t.Fatalf("remove user pack status=%d body=%s", respRemove.StatusCode, string(bodyRemove))
	}
	var rmRes simpleSuccessResponse
	if err := testutil.DecodeJSON(bodyRemove, &rmRes); err != nil {
		t.Fatalf("decode remove user pack: %v body=%s", err, string(bodyRemove))
	}
	if !rmRes.Success {
		t.Fatalf("expected remove success=true, body=%s", string(bodyRemove))
	}

	// remove again => 404
	respRemove2, bodyRemove2, err := c.DoJSON("DELETE", "/emoji-packs/"+created.ID+"/remove", nil, login.Token)
	if err != nil {
		t.Fatalf("remove user pack2 http error: %v", err)
	}
	if respRemove2.StatusCode != 404 {
		t.Fatalf("expected remove again status=404, got %d body=%s", respRemove2.StatusCode, string(bodyRemove2))
	}
}
