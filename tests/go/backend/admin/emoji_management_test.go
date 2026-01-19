package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

// 表情包管理测试

func TestEmojiPacks_List(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, body, err := c.DoJSON("GET", "/api/admin/emoji-packs", nil, admin.Token)
	if err != nil {
		t.Fatalf("list emoji packs http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("list emoji packs status=%d body=%s", resp.StatusCode, string(body))
	}
}

func TestEmojiPacks_GetById_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("GET", "/api/admin/emoji-packs/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("get emoji pack http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestEmojiPacks_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"name": "Updated Pack",
	}
	resp, _, err := c.DoJSON("PATCH", "/api/admin/emoji-packs/00000000-0000-0000-0000-000000000000", payload, admin.Token)
	if err != nil {
		t.Fatalf("update emoji pack http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestEmojiPacks_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/emoji-packs/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete emoji pack http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

// 表情项测试

func TestEmojiItems_Create_InvalidPack(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"pack_id": "00000000-0000-0000-0000-000000000000",
		"name":    "test-emoji",
		"url":     "https://example.com/emoji.png",
	}
	resp, _, err := c.DoJSON("POST", "/api/admin/emoji-items", payload, admin.Token)
	if err != nil {
		t.Fatalf("create emoji item http error: %v", err)
	}
	// 应该返回 400 或 404（包不存在）
	if resp.StatusCode != 400 && resp.StatusCode != 404 && resp.StatusCode != 422 {
		t.Fatalf("expected 400/404/422, got %d", resp.StatusCode)
	}
}

func TestEmojiItems_GetById_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("GET", "/api/admin/emoji-items/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("get emoji item http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestEmojiItems_Update_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	payload := map[string]any{
		"name": "Updated Emoji",
	}
	resp, _, err := c.DoJSON("PATCH", "/api/admin/emoji-items/00000000-0000-0000-0000-000000000000", payload, admin.Token)
	if err != nil {
		t.Fatalf("update emoji item http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestEmojiItems_Delete_NotFound(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)

	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp, _, err := c.DoJSON("DELETE", "/api/admin/emoji-items/00000000-0000-0000-0000-000000000000", nil, admin.Token)
	if err != nil {
		t.Fatalf("delete emoji item http error: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}
