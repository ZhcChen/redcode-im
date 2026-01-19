package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

// 使用 /members/add 路径添加成员（备用路径测试）
func TestAddMembersViaAddPath_Success(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	existingMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	newMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "add-path-test-"+time.Now().Format("150405"), []string{existingMember.ID})

	// 使用 /members/add 路径
	payload := map[string]any{
		"user_ids": []string{newMember.ID},
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members/add", payload, ownerLogin.Token)
	if err != nil {
		t.Fatalf("add members http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("add members status=%d body=%s", resp.StatusCode, string(body))
	}

	var result struct {
		Success      bool     `json:"success"`
		AddedUserIDs []string `json:"added_user_ids"`
	}
	if err := testutil.DecodeJSON(body, &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !result.Success {
		t.Fatal("expected success=true")
	}
	if !slices.Contains(result.AddedUserIDs, newMember.ID) {
		t.Fatalf("expected %s in added_user_ids, got %v", newMember.ID, result.AddedUserIDs)
	}
}

func TestAddMembersViaAddPath_NoPermission(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	target := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "add-path-perm-"+time.Now().Format("150405"), []string{member.ID})

	// 普通成员尝试添加他人
	payload := map[string]any{
		"user_ids": []string{target.ID},
	}
	resp, _, err := c.DoJSON("POST", "/rooms/"+roomID+"/members/add", payload, memberLogin.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	if resp.StatusCode != 403 {
		t.Fatalf("expected 403, got %d", resp.StatusCode)
	}
}

func TestAddMembersViaAddPath_EmptyUserIds(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	existingMember := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	ownerLogin := testutil.Login(t, c, owner.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "add-path-empty-"+time.Now().Format("150405"), []string{existingMember.ID})

	// 空 user_ids
	payload := map[string]any{
		"user_ids": []string{},
	}
	resp, body, err := c.DoJSON("POST", "/rooms/"+roomID+"/members/add", payload, ownerLogin.Token)
	if err != nil {
		t.Fatalf("http error: %v", err)
	}
	// 可能返回 200（成功但无操作）或 400（验证失败）
	if resp.StatusCode != 200 && resp.StatusCode != 400 {
		t.Fatalf("expected 200 or 400, got %d body=%s", resp.StatusCode, string(body))
	}
}
