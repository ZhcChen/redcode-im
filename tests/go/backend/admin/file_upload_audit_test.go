package admin_test

import (
	"net/url"
	"os"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type avatarDirectUploadResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Key     *string `json:"key"`
}

type auditTaskListResp struct {
	Tasks []struct {
		ID      string `json:"id"`
		ObjectKey string `json:"object_key"`
	} `json:"tasks"`
	Total  int64 `json:"total"`
	Limit  int64 `json:"limit"`
	Offset int64 `json:"offset"`
}

type auditTaskDetailResp struct {
	Task struct {
		ID        string `json:"id"`
		ObjectKey string `json:"object_key"`
		Status    int    `json:"status"`
	} `json:"task"`
}

type auditTaskRequeueResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestAdmin_FileUploadAuditTasks_ListGetRequeue(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip file upload audit tasks test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	// 触发一条审核任务：用户头像直传 + commit
	pass := "Passw0rd!"
	user := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	login := testutil.Login(t, c, user.Username, pass)

	resp1, body1, err := c.DoJSON("POST", "/users/me/avatar/direct-upload", map[string]any{
		"content_type": "image/png",
		"file_size":    1024,
		"hash_value":   strings.Repeat("0", 32),
		"hash_alg":     1,
	}, login.Token)
	if err != nil {
		t.Fatalf("avatar direct-upload http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("avatar direct-upload status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var du avatarDirectUploadResp
	if err := testutil.DecodeJSON(body1, &du); err != nil {
		t.Fatalf("decode avatar direct-upload: %v body=%s", err, string(body1))
	}
	if !du.Success || du.Key == nil || *du.Key == "" {
		t.Fatalf("unexpected avatar direct-upload resp: %+v body=%s", du, string(body1))
	}

	resp2, body2, err := c.DoJSON("POST", "/users/me/avatar/commit", map[string]any{
		"key":                *du.Key,
		"expires_in_seconds": 60,
	}, login.Token)
	if err != nil {
		t.Fatalf("avatar commit http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("avatar commit status=%d body=%s", resp2.StatusCode, string(body2))
	}

	// 管理端查询审核任务（按 object_key 过滤）
	listPath := "/api/admin/file-upload-audit/tasks?limit=10&offset=0&keyword=" + url.QueryEscape(*du.Key)
	resp3, body3, err := c.DoJSON("GET", listPath, nil, admin.Token)
	if err != nil {
		t.Fatalf("list audit tasks http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("list audit tasks status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var list auditTaskListResp
	if err := testutil.DecodeJSON(body3, &list); err != nil {
		t.Fatalf("decode list audit tasks: %v body=%s", err, string(body3))
	}
	if list.Total <= 0 || len(list.Tasks) == 0 {
		t.Fatalf("expected audit tasks non-empty, got %+v body=%s", list, string(body3))
	}

	taskID := list.Tasks[0].ID
	if taskID == "" {
		t.Fatalf("expected task id non-empty, body=%s", string(body3))
	}

	// 详情
	resp4, body4, err := c.DoJSON("GET", "/api/admin/file-upload-audit/tasks/"+taskID, nil, admin.Token)
	if err != nil {
		t.Fatalf("get audit task http error: %v", err)
	}
	if resp4.StatusCode != 200 {
		t.Fatalf("get audit task status=%d body=%s", resp4.StatusCode, string(body4))
	}
	var detail auditTaskDetailResp
	if err := testutil.DecodeJSON(body4, &detail); err != nil {
		t.Fatalf("decode audit task detail: %v body=%s", err, string(body4))
	}
	if detail.Task.ID != taskID {
		t.Fatalf("expected task.id=%s, got %s body=%s", taskID, detail.Task.ID, string(body4))
	}

	// requeue
	resp5, body5, err := c.DoJSON("POST", "/api/admin/file-upload-audit/tasks/"+taskID+"/requeue", map[string]any{}, admin.Token)
	if err != nil {
		t.Fatalf("requeue audit task http error: %v", err)
	}
	if resp5.StatusCode != 200 {
		t.Fatalf("requeue audit task status=%d body=%s", resp5.StatusCode, string(body5))
	}
	var rq auditTaskRequeueResp
	if err := testutil.DecodeJSON(body5, &rq); err != nil {
		t.Fatalf("decode requeue resp: %v body=%s", err, string(body5))
	}
	if !rq.Success {
		t.Fatalf("expected requeue success=true, got %+v body=%s", rq, string(body5))
	}
}

