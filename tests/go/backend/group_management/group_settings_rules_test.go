package group_management_test

import (
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type groupSettingsResponse struct {
	Settings struct {
		RoomID               string `json:"room_id"`
		JoinApprovalRequired bool   `json:"join_approval_required"`
		MaxMembers           int    `json:"max_members"`
	} `json:"settings"`
}

type createRuleResponse struct {
	Rule struct {
		ID      string `json:"id"`
		RoomID  string `json:"room_id"`
		Title   string `json:"title"`
		Content string `json:"content"`
	} `json:"rule"`
}

type listRulesResponse struct {
	Rules []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
	} `json:"rules"`
}

func TestGroupManagement_SettingsAndRules(t *testing.T) {
	c := testutil.NewClient()
	pass := "Passw0rd!"

	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-gm-"+time.Now().Format("150405"), []string{user2.ID})

	// get settings (auto create row)
	respGet, bodyGet, err := c.DoJSON("GET", "/rooms/"+roomID+"/settings", nil, login1.Token)
	if err != nil {
		t.Fatalf("get group settings http error: %v", err)
	}
	if respGet.StatusCode != 200 {
		t.Fatalf("get group settings status=%d body=%s", respGet.StatusCode, string(bodyGet))
	}
	var gs groupSettingsResponse
	if err := testutil.DecodeJSON(bodyGet, &gs); err != nil {
		t.Fatalf("decode group settings: %v body=%s", err, string(bodyGet))
	}
	if gs.Settings.RoomID != roomID {
		t.Fatalf("expected settings.room_id=%s, got %s body=%s", roomID, gs.Settings.RoomID, string(bodyGet))
	}

	// update settings (owner)
	respUpd, bodyUpd, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/settings", map[string]any{
		"join_approval_required": true,
		"max_members":            50,
	}, login1.Token)
	if err != nil {
		t.Fatalf("update group settings http error: %v", err)
	}
	if respUpd.StatusCode != 200 {
		t.Fatalf("update group settings status=%d body=%s", respUpd.StatusCode, string(bodyUpd))
	}
	var gs2 groupSettingsResponse
	if err := testutil.DecodeJSON(bodyUpd, &gs2); err != nil {
		t.Fatalf("decode updated group settings: %v body=%s", err, string(bodyUpd))
	}
	if !gs2.Settings.JoinApprovalRequired || gs2.Settings.MaxMembers != 50 {
		t.Fatalf("unexpected updated settings: %+v body=%s", gs2.Settings, string(bodyUpd))
	}

	// update settings forbidden for non-manager
	respForbidden, bodyForbidden, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/settings", map[string]any{
		"join_approval_required": false,
	}, login2.Token)
	if err != nil {
		t.Fatalf("update group settings (non-manager) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected update group settings (non-manager) status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}

	// create rule
	respCreate, bodyCreate, err := c.DoJSON("POST", "/rooms/"+roomID+"/rules", map[string]any{
		"title":   "No spam",
		"content": "Be nice",
	}, login1.Token)
	if err != nil {
		t.Fatalf("create rule http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create rule status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var cr createRuleResponse
	if err := testutil.DecodeJSON(bodyCreate, &cr); err != nil {
		t.Fatalf("decode create rule: %v body=%s", err, string(bodyCreate))
	}
	if cr.Rule.ID == "" || cr.Rule.RoomID != roomID {
		t.Fatalf("unexpected create rule response: %+v body=%s", cr.Rule, string(bodyCreate))
	}

	// list rules
	respList, bodyList, err := c.DoJSON("GET", "/rooms/"+roomID+"/rules", nil, login1.Token)
	if err != nil {
		t.Fatalf("list rules http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list rules status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var lr listRulesResponse
	if err := testutil.DecodeJSON(bodyList, &lr); err != nil {
		t.Fatalf("decode list rules: %v body=%s", err, string(bodyList))
	}
	found := false
	for _, r := range lr.Rules {
		if r.ID == cr.Rule.ID {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected rule id=%s in list, body=%s", cr.Rule.ID, string(bodyList))
	}

	// update rule
	respRuleUpd, bodyRuleUpd, err := c.DoJSON("PATCH", "/rooms/"+roomID+"/rules/"+cr.Rule.ID, map[string]any{
		"title": "No spam v2",
	}, login1.Token)
	if err != nil {
		t.Fatalf("update rule http error: %v", err)
	}
	if respRuleUpd.StatusCode != 200 {
		t.Fatalf("update rule status=%d body=%s", respRuleUpd.StatusCode, string(bodyRuleUpd))
	}
	var cr2 createRuleResponse
	if err := testutil.DecodeJSON(bodyRuleUpd, &cr2); err != nil {
		t.Fatalf("decode updated rule: %v body=%s", err, string(bodyRuleUpd))
	}
	if cr2.Rule.Title != "No spam v2" {
		t.Fatalf("expected updated title, got %q body=%s", cr2.Rule.Title, string(bodyRuleUpd))
	}

	// delete rule
	respDel, bodyDel, err := c.DoJSON("DELETE", "/rooms/"+roomID+"/rules/"+cr.Rule.ID, nil, login1.Token)
	if err != nil {
		t.Fatalf("delete rule http error: %v", err)
	}
	if respDel.StatusCode != 204 {
		t.Fatalf("expected delete rule status=204, got %d body=%s", respDel.StatusCode, string(bodyDel))
	}

	// non-manager cannot create rule
	respCreateForbidden, bodyCreateForbidden, err := c.DoJSON("POST", "/rooms/"+roomID+"/rules", map[string]any{
		"title":   "x",
		"content": "y",
	}, login2.Token)
	if err != nil {
		t.Fatalf("create rule (non-manager) http error: %v", err)
	}
	if respCreateForbidden.StatusCode != 403 {
		t.Fatalf("expected create rule (non-manager) status=403, got %d body=%s", respCreateForbidden.StatusCode, string(bodyCreateForbidden))
	}
}
