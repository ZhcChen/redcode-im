package reports_test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type reportAttachmentSignatureResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Key     *string `json:"key"`
	Signature *struct {
		URL     string            `json:"url"`
		Method  string            `json:"method"`
		Headers map[string]string `json:"headers"`
		Key     string            `json:"key"`
	} `json:"signature"`
}

type reportAttachmentCommitResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type createReportResp struct {
	Success  bool   `json:"success"`
	Message  string `json:"message"`
	ReportID string `json:"report_id"`
}

type adminReportListResp struct {
	Reports []struct {
		ID         string `json:"id"`
		ReporterID string `json:"reporterId"`
		TargetType string `json:"targetType"`
		TargetID   string `json:"targetId"`
		Content    string `json:"content"`
	} `json:"reports"`
	Total int64 `json:"total"`
}

func TestReports_CreateReport_UserFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip reports test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login1 := testutil.Login(t, c, user1.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-report-"+time.Now().Format("150405"), []string{user2.ID})

	// 1) 生成截图签名
	respSig, bodySig, err := c.DoJSON("POST", "/reports/attachments/signature", map[string]any{
		"filename":     "evidence.png",
		"content_type": "image/png",
		"file_size":    123,
	}, login1.Token)
	if err != nil {
		t.Fatalf("report attachment signature http error: %v", err)
	}
	if respSig.StatusCode != 200 {
		t.Fatalf("report attachment signature status=%d body=%s", respSig.StatusCode, string(bodySig))
	}
	var sig reportAttachmentSignatureResp
	if err := testutil.DecodeJSON(bodySig, &sig); err != nil {
		t.Fatalf("decode report signature: %v body=%s", err, string(bodySig))
	}
	if !sig.Success || sig.Key == nil || *sig.Key == "" || sig.Signature == nil || sig.Signature.URL == "" {
		t.Fatalf("unexpected report signature resp: %+v body=%s", sig, string(bodySig))
	}

	// 2) commit（测试栈会跳过真实 COS 校验；这里仍走完整 API 链路）
	respCommit, bodyCommit, err := c.DoJSON("POST", "/reports/attachments/commit", map[string]any{
		"key":       *sig.Key,
		"file_size": 123,
	}, login1.Token)
	if err != nil {
		t.Fatalf("report attachment commit http error: %v", err)
	}
	if respCommit.StatusCode != 200 {
		t.Fatalf("report attachment commit status=%d body=%s", respCommit.StatusCode, string(bodyCommit))
	}
	var commit reportAttachmentCommitResp
	if err := testutil.DecodeJSON(bodyCommit, &commit); err != nil {
		t.Fatalf("decode report commit: %v body=%s", err, string(bodyCommit))
	}
	if !commit.Success {
		t.Fatalf("expected report attachment commit success=true, body=%s", string(bodyCommit))
	}

	// 3) 创建举报（target=room）
	content := "go-test report"
	respCreate, bodyCreate, err := c.DoJSON("POST", "/reports", map[string]any{
		"target_type":     "room",
		"target_id":       roomID,
		"content":         content,
		"attachment_keys": []string{*sig.Key},
	}, login1.Token)
	if err != nil {
		t.Fatalf("create report http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create report status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created createReportResp
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode create report: %v body=%s", err, string(bodyCreate))
	}
	if !created.Success || created.ReportID == "" {
		t.Fatalf("unexpected create report resp: %+v body=%s", created, string(bodyCreate))
	}

	// 4) 管理端可查询到该举报
	url := fmt.Sprintf("/api/admin/reports?page=1&page_size=20&reporterId=%s", user1.ID)
	respList, bodyList, err := c.DoJSON("GET", url, nil, admin.Token)
	if err != nil {
		t.Fatalf("admin list reports http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("admin list reports status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list adminReportListResp
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode admin list reports: %v body=%s", err, string(bodyList))
	}
	found := false
	for _, item := range list.Reports {
		if item.ID == created.ReportID {
			found = true
			if item.ReporterID != user1.ID || item.TargetType != "room" || item.TargetID != roomID || item.Content != content {
				t.Fatalf("unexpected report item: %+v", item)
			}
			break
		}
	}
	if !found {
		t.Fatalf("expected report_id=%s in admin list, got total=%d body=%s", created.ReportID, list.Total, string(bodyList))
	}
}

