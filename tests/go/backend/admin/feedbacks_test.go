package admin_test

import (
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type submitFeedbackResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type feedbackListResponse struct {
	Feedbacks []struct {
		ID      string `json:"id"`
		UserID  string `json:"userId"`
		Content string `json:"content"`
	} `json:"feedbacks"`
	Total    int64 `json:"total"`
	Page     int   `json:"page"`
	PageSize int   `json:"pageSize"`
}

func TestAdmin_Feedbacks_SubmitAndList(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin feedbacks test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	// empty content => 400
	respBad, bodyBad, err := c.DoJSON("POST", "/feedbacks", map[string]any{
		"content": "",
	}, login.Token)
	if err != nil {
		t.Fatalf("submit feedback (empty) http error: %v", err)
	}
	if respBad.StatusCode != 400 {
		t.Fatalf("expected submit feedback (empty) status=400, got %d body=%s", respBad.StatusCode, string(bodyBad))
	}

	// ok
	keyword := "go-feedback-" + time.Now().Format("20060102150405.000000000")
	respOK, bodyOK, err := c.DoJSON("POST", "/feedbacks", map[string]any{
		"content": keyword + " hello",
		"contact": "go-test@example.com",
	}, login.Token)
	if err != nil {
		t.Fatalf("submit feedback http error: %v", err)
	}
	if respOK.StatusCode != 200 {
		t.Fatalf("submit feedback status=%d body=%s", respOK.StatusCode, string(bodyOK))
	}
	var submit submitFeedbackResponse
	if err := testutil.DecodeJSON(bodyOK, &submit); err != nil {
		t.Fatalf("decode submit feedback: %v body=%s", err, string(bodyOK))
	}
	if !submit.Success {
		t.Fatalf("expected submit feedback success=true, body=%s", string(bodyOK))
	}

	// list with keyword filter
	respList, bodyList, err := c.DoJSON("GET", "/api/admin/feedbacks?page=1&page_size=20&keyword="+keyword, nil, admin.Token)
	if err != nil {
		t.Fatalf("list feedbacks http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("list feedbacks status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list feedbackListResponse
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode list feedbacks: %v body=%s", err, string(bodyList))
	}
	if list.Page != 1 || list.PageSize <= 0 {
		t.Fatalf("unexpected paging: page=%d pageSize=%d body=%s", list.Page, list.PageSize, string(bodyList))
	}
	if list.Total <= 0 || len(list.Feedbacks) == 0 {
		t.Fatalf("expected feedbacks non-empty: total=%d len=%d body=%s", list.Total, len(list.Feedbacks), string(bodyList))
	}
	found := false
	for _, f := range list.Feedbacks {
		if f.UserID == user.ID && strings.Contains(f.Content, keyword) {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected feedback for user=%s with keyword=%s, body=%s", user.ID, keyword, string(bodyList))
	}

	// list with user filter
	respList2, bodyList2, err := c.DoJSON("GET", "/api/admin/feedbacks?page=1&page_size=20&user_id="+user.ID, nil, admin.Token)
	if err != nil {
		t.Fatalf("list feedbacks (user filter) http error: %v", err)
	}
	if respList2.StatusCode != 200 {
		t.Fatalf("list feedbacks (user filter) status=%d body=%s", respList2.StatusCode, string(bodyList2))
	}
	var list2 feedbackListResponse
	if err := testutil.DecodeJSON(bodyList2, &list2); err != nil {
		t.Fatalf("decode list feedbacks (user filter): %v body=%s", err, string(bodyList2))
	}
	if list2.Total <= 0 || len(list2.Feedbacks) == 0 {
		t.Fatalf("expected feedbacks non-empty with user filter: total=%d len=%d body=%s", list2.Total, len(list2.Feedbacks), string(bodyList2))
	}

	// non-admin forbidden
	respForbidden, bodyForbidden, err := c.DoJSON("GET", "/api/admin/feedbacks?page=1&page_size=1", nil, login.Token)
	if err != nil {
		t.Fatalf("list feedbacks (non-admin) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected non-admin status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}
}
