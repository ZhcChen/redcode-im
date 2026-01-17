package rooms_test

import (
	"slices"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type transferOwnerResp struct {
	RoomID  string `json:"room_id"`
	OwnerID string `json:"owner_id"`
}

type dissolveRoomResp struct {
	Success bool `json:"success"`
}

type removeMemberResp struct {
	Success bool `json:"success"`
}

func TestRooms_TransferOwner_OnlyOwnerCanTransfer(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	third := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)
	thirdLogin := testutil.Login(t, c, third.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-transfer-"+time.Now().Format("150405"), []string{member.ID, third.ID})

	// 非群主不能转让群主
	resp0, body0, err := c.DoJSON("POST", "/rooms/"+roomID+"/transfer", map[string]any{"new_owner_id": third.ID}, memberLogin.Token)
	if err != nil {
		t.Fatalf("member transfer owner http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected member transfer status=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	resp1, body1, err := c.DoJSON("POST", "/rooms/"+roomID+"/transfer", map[string]any{"new_owner_id": member.ID}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner transfer http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("owner transfer status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var tr transferOwnerResp
	if err := testutil.DecodeJSON(body1, &tr); err != nil {
		t.Fatalf("decode transfer resp: %v body=%s", err, string(body1))
	}
	if tr.RoomID != roomID || tr.OwnerID != member.ID {
		t.Fatalf("unexpected transfer resp: %+v want room_id=%s owner_id=%s", tr, roomID, member.ID)
	}

	// 旧群主已降级为普通成员：不允许 update_room
	resp2, body2, err := c.DoJSON("PATCH", "/rooms/"+roomID, map[string]any{"name": "forbidden"}, ownerLogin.Token)
	if err != nil {
		t.Fatalf("old owner update room http error: %v", err)
	}
	if resp2.StatusCode != 403 {
		t.Fatalf("expected old owner update status=403, got %d body=%s", resp2.StatusCode, string(body2))
	}

	// 新群主可以 update_room
	newName := "go-transfer-new-" + time.Now().Format("150405.000000000")
	resp3, body3, err := c.DoJSON("PATCH", "/rooms/"+roomID, map[string]any{"name": newName}, memberLogin.Token)
	if err != nil {
		t.Fatalf("new owner update room http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("new owner update room status=%d body=%s", resp3.StatusCode, string(body3))
	}

	// 其他成员也不允许 update_room
	resp4, body4, err := c.DoJSON("PATCH", "/rooms/"+roomID, map[string]any{"name": "nope"}, thirdLogin.Token)
	if err != nil {
		t.Fatalf("third update room http error: %v", err)
	}
	if resp4.StatusCode != 403 {
		t.Fatalf("expected third update status=403, got %d body=%s", resp4.StatusCode, string(body4))
	}
}

func TestRooms_DissolveGroup_OwnerOnly(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	member := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	memberLogin := testutil.Login(t, c, member.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-dissolve-"+time.Now().Format("150405"), []string{member.ID})

	beforeOwner := listMyRooms(t, c, ownerLogin.Token)
	if !slices.ContainsFunc(beforeOwner, func(r myRoom) bool { return r.ID == roomID }) {
		t.Fatalf("expected room in owner rooms before dissolve, got %+v", beforeOwner)
	}

	// 非群主不能解散
	resp0, body0, err := c.DoJSON("DELETE", "/rooms/"+roomID, nil, memberLogin.Token)
	if err != nil {
		t.Fatalf("member dissolve room http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected member dissolve status=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	resp1, body1, err := c.DoJSON("DELETE", "/rooms/"+roomID, nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner dissolve room http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("owner dissolve status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var dr dissolveRoomResp
	if err := testutil.DecodeJSON(body1, &dr); err != nil {
		t.Fatalf("decode dissolve resp: %v body=%s", err, string(body1))
	}
	if !dr.Success {
		t.Fatalf("expected dissolve success=true, got false body=%s", string(body1))
	}

	afterOwner := listMyRooms(t, c, ownerLogin.Token)
	if slices.ContainsFunc(afterOwner, func(r myRoom) bool { return r.ID == roomID }) {
		t.Fatalf("expected room removed from owner rooms, got %+v", afterOwner)
	}
	afterMember := listMyRooms(t, c, memberLogin.Token)
	if slices.ContainsFunc(afterMember, func(r myRoom) bool { return r.ID == roomID }) {
		t.Fatalf("expected room removed from member rooms, got %+v", afterMember)
	}
}

func TestRooms_RemoveMember_OwnerOrAdminOnly(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	owner := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	adminCandidate := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	victim := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	ownerLogin := testutil.Login(t, c, owner.Username, pass)
	adminLogin := testutil.Login(t, c, adminCandidate.Username, pass)
	victimLogin := testutil.Login(t, c, victim.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, ownerLogin.Token, "go-kick-"+time.Now().Format("150405"), []string{adminCandidate.ID, victim.ID})

	// 普通成员无权移除他人
	resp0, body0, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/members/"+victim.ID, nil, adminLogin.Token)
	if err != nil {
		t.Fatalf("member remove member http error: %v", err)
	}
	if resp0.StatusCode != 403 {
		t.Fatalf("expected member remove status=403, got %d body=%s", resp0.StatusCode, string(body0))
	}

	// 群主不能移除自己
	resp1, body1, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/members/"+owner.ID, nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner remove self http error: %v", err)
	}
	if resp1.StatusCode != 403 {
		t.Fatalf("expected remove owner status=403, got %d body=%s", resp1.StatusCode, string(body1))
	}

	// 群主移除成员
	resp2, body2, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/members/"+victim.ID, nil, ownerLogin.Token)
	if err != nil {
		t.Fatalf("owner remove victim http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("owner remove victim status=%d body=%s", resp2.StatusCode, string(body2))
	}
	var rm removeMemberResp
	if err := testutil.DecodeJSON(body2, &rm); err != nil {
		t.Fatalf("decode remove member resp: %v body=%s", err, string(body2))
	}
	if !rm.Success {
		t.Fatalf("expected remove member success=true, got false body=%s", string(body2))
	}

	// 被移除后：无法再获取房间详情/成员列表/消息
	resp3, body3, err := c.DoJSON("GET", "/rooms/"+roomID, nil, victimLogin.Token)
	if err != nil {
		t.Fatalf("victim get room http error: %v", err)
	}
	if resp3.StatusCode != 403 {
		t.Fatalf("expected victim get room status=403, got %d body=%s", resp3.StatusCode, string(body3))
	}

	resp4, body4, err := c.DoJSON("GET", "/rooms/"+roomID+"/members", nil, victimLogin.Token)
	if err != nil {
		t.Fatalf("victim list members http error: %v", err)
	}
	if resp4.StatusCode != 403 {
		t.Fatalf("expected victim list members status=403, got %d body=%s", resp4.StatusCode, string(body4))
	}

	resp5, body5, err := c.DoJSON("GET", "/rooms/"+roomID+"/messages", nil, victimLogin.Token)
	if err != nil {
		t.Fatalf("victim list messages http error: %v", err)
	}
	if resp5.StatusCode != 403 {
		t.Fatalf("expected victim list messages status=403, got %d body=%s", resp5.StatusCode, string(body5))
	}
}
