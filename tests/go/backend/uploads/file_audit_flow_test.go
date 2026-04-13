package uploads_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type auditTaskListResponse struct {
	Tasks []struct {
		ID             string  `json:"id"`
		ObjectKey      string  `json:"objectKey"`
		Status         int     `json:"status"`
		VendorJobID    *string `json:"vendorJobId"`
		RejectedReason *string `json:"rejectedReason"`
		Attempts       int     `json:"attempts"`
		LastError      *string `json:"lastError"`
	} `json:"tasks"`
	Total int `json:"total"`
}

type auditTaskDetailResponse struct {
	Task struct {
		ID             string         `json:"id"`
		ObjectKey      string         `json:"objectKey"`
		Status         int            `json:"status"`
		VendorJobID    *string        `json:"vendorJobId"`
		RejectedReason *string        `json:"rejectedReason"`
		Result         map[string]any `json:"result"`
	} `json:"task"`
}

func TestFileUploadAuditTaskLifecycle_ApprovesExistingB2Object(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)
	admin := testutil.AdminLogin(t, c)

	suffix := fmt.Sprintf("%d", time.Now().UnixNano()%1_000_000_000)
	key := "reports/existing-audit-" + suffix + ".png"

	uploadReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/api/admin/storage-providers/test/upload", admin.Token, map[string]any{
		"key":          key,
		"content":      "mock-violation-content",
		"content_type": "image/png",
	})
	uploadResp, err := c.HTTP.Do(uploadReq)
	if err != nil {
		t.Fatalf("admin test upload failed: %v", err)
	}
	defer uploadResp.Body.Close()
	if uploadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(uploadResp.Body)
		t.Fatalf("admin test upload expect 200, got %d: %s", uploadResp.StatusCode, string(body))
	}
	var uploadPayload struct {
		Success bool   `json:"success"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(uploadResp.Body).Decode(&uploadPayload); err != nil {
		t.Fatalf("decode admin test upload response failed: %v", err)
	}
	if !uploadPayload.Success {
		t.Fatalf("admin test upload success=false: %+v", uploadPayload)
	}

	task, ok := waitAuditTaskApproved(t, c, admin.Token, key, 90*time.Second)
	if !ok {
		t.Fatalf("audit task did not reach approved status in time, key=%s", key)
	}

	detailReq := testutil.NewAuthedJSONRequestWithToken(http.MethodGet, c.BaseURL+"/api/admin/file-upload-audit/tasks/"+task.ID, admin.Token, nil)
	detailResp, err := c.HTTP.Do(detailReq)
	if err != nil {
		t.Fatalf("get audit task detail failed: %v", err)
	}
	defer detailResp.Body.Close()
	if detailResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(detailResp.Body)
		t.Fatalf("get audit task detail expect 200, got %d: %s", detailResp.StatusCode, string(body))
	}
	var detailPayload auditTaskDetailResponse
	if err := json.NewDecoder(detailResp.Body).Decode(&detailPayload); err != nil {
		t.Fatalf("decode audit task detail failed: %v", err)
	}
	if detailPayload.Task.ID != task.ID || detailPayload.Task.ObjectKey != key {
		t.Fatalf("audit detail mismatch: %+v", detailPayload.Task)
	}
	if detailPayload.Task.Status != 1 {
		t.Fatalf("audit detail expect approved status=1, got %d", detailPayload.Task.Status)
	}
	if detailPayload.Task.RejectedReason != nil && strings.TrimSpace(*detailPayload.Task.RejectedReason) != "" {
		t.Fatalf("audit detail rejected_reason should be empty: %+v", detailPayload.Task)
	}
	if detailPayload.Task.VendorJobID != nil && strings.TrimSpace(*detailPayload.Task.VendorJobID) != "" {
		t.Fatalf("audit detail vendor_job_id should be empty for B2 head check: %+v", detailPayload.Task)
	}
	if len(detailPayload.Task.Result) == 0 {
		t.Fatalf("audit detail result should not be empty")
	}
	if detailPayload.Task.Result["vendor"] != "backblaze_b2" {
		t.Fatalf("audit detail vendor mismatch: %+v", detailPayload.Task.Result)
	}
	if detailPayload.Task.Result["check"] != "head_object" {
		t.Fatalf("audit detail check mismatch: %+v", detailPayload.Task.Result)
	}

	existsReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/api/admin/storage-providers/test/exists", admin.Token, map[string]any{
		"key": key,
	})
	existsResp, err := c.HTTP.Do(existsReq)
	if err != nil {
		t.Fatalf("check object exists failed: %v", err)
	}
	defer existsResp.Body.Close()
	if existsResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(existsResp.Body)
		t.Fatalf("check object exists expect 200, got %d: %s", existsResp.StatusCode, string(body))
	}
	var existsPayload struct {
		Success bool `json:"success"`
		Exists  bool `json:"exists"`
	}
	if err := json.NewDecoder(existsResp.Body).Decode(&existsPayload); err != nil {
		t.Fatalf("decode object exists response failed: %v", err)
	}
	if !existsPayload.Success {
		t.Fatalf("object exists response success=false: %+v", existsPayload)
	}
	if !existsPayload.Exists {
		t.Fatalf("approved object should still exist after audit, key=%s", key)
	}

	requeueReq := testutil.NewAuthedJSONRequestWithToken(http.MethodPost, c.BaseURL+"/api/admin/file-upload-audit/tasks/"+task.ID+"/requeue", admin.Token, nil)
	requeueResp, err := c.HTTP.Do(requeueReq)
	if err != nil {
		t.Fatalf("requeue audit task failed: %v", err)
	}
	defer requeueResp.Body.Close()
	if requeueResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(requeueResp.Body)
		t.Fatalf("requeue audit task expect 200, got %d: %s", requeueResp.StatusCode, string(body))
	}
	var requeuePayload struct {
		Success bool   `json:"success"`
		Message string `json:"message"`
	}
	if err := json.NewDecoder(requeueResp.Body).Decode(&requeuePayload); err != nil {
		t.Fatalf("decode requeue response failed: %v", err)
	}
	if !requeuePayload.Success {
		t.Fatalf("requeue response success=false: %+v", requeuePayload)
	}
}

func waitAuditTaskApproved(t *testing.T, c *testutil.Client, adminToken, objectKey string, timeout time.Duration) (task struct {
	ID             string
	ObjectKey      string
	Status         int
	VendorJobID    *string
	RejectedReason *string
	Attempts       int
	LastError      *string
}, ok bool) {
	t.Helper()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		listReq := testutil.NewAuthedJSONRequestWithToken(http.MethodGet, c.BaseURL+"/api/admin/file-upload-audit/tasks?keyword="+url.QueryEscape(objectKey)+"&limit=20", adminToken, nil)
		listResp, err := c.HTTP.Do(listReq)
		if err != nil {
			t.Fatalf("list audit tasks failed: %v", err)
		}

		var payload auditTaskListResponse
		if listResp.StatusCode == http.StatusOK {
			if err := json.NewDecoder(listResp.Body).Decode(&payload); err != nil {
				listResp.Body.Close()
				t.Fatalf("decode audit task list failed: %v", err)
			}
		} else {
			body, _ := io.ReadAll(listResp.Body)
			listResp.Body.Close()
			t.Fatalf("list audit tasks expect 200, got %d: %s", listResp.StatusCode, string(body))
		}
		listResp.Body.Close()

		for _, item := range payload.Tasks {
			if item.ObjectKey != objectKey {
				continue
			}

			task = struct {
				ID             string
				ObjectKey      string
				Status         int
				VendorJobID    *string
				RejectedReason *string
				Attempts       int
				LastError      *string
			}{
				ID:             item.ID,
				ObjectKey:      item.ObjectKey,
				Status:         item.Status,
				VendorJobID:    item.VendorJobID,
				RejectedReason: item.RejectedReason,
				Attempts:       item.Attempts,
				LastError:      item.LastError,
			}

			if item.Status == 1 {
				return task, true
			}

			if item.Status == 4 {
				lastError := ""
				if item.LastError != nil {
					lastError = *item.LastError
				}
				t.Fatalf("audit task entered failed status=4 unexpectedly, key=%s, last_error=%s", objectKey, lastError)
			}
		}

		time.Sleep(3 * time.Second)
	}

	return task, false
}
