package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type fileManagementStats struct {
	TotalFiles     int64 `json:"total_files"`
	TotalSizeBytes int64 `json:"total_size_bytes"`
}

type fileListResponse struct {
	Files []struct {
		ID        string `json:"id"`
		ObjectKey string `json:"object_key"`
	} `json:"files"`
	Total int `json:"total"`
	Page  int `json:"page"`
}

type fileOperationResponse struct {
	Success      bool   `json:"success"`
	Message      string `json:"message"`
	DeletedCount *int   `json:"deleted_count"`
}

func TestAdmin_FileManagement_StatsListAndDelete(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin file management test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respStats, bodyStats, err := c.DoJSON("GET", "/api/admin/files/stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("file stats http error: %v", err)
	}
	if respStats.StatusCode != 200 {
		t.Fatalf("file stats status=%d body=%s", respStats.StatusCode, string(bodyStats))
	}
	var stats fileManagementStats
	if err := testutil.DecodeJSON(bodyStats, &stats); err != nil {
		t.Fatalf("decode file stats: %v body=%s", err, string(bodyStats))
	}
	if stats.TotalFiles < 0 || stats.TotalSizeBytes < 0 {
		t.Fatalf("expected total_files/total_size_bytes >=0, got %+v body=%s", stats, string(bodyStats))
	}

	respList, bodyList, err := c.DoJSON("GET", "/api/admin/files?page=1&page_size=10", nil, admin.Token)
	if err != nil {
		t.Fatalf("file list http error: %v", err)
	}
	if respList.StatusCode != 200 {
		t.Fatalf("file list status=%d body=%s", respList.StatusCode, string(bodyList))
	}
	var list fileListResponse
	if err := testutil.DecodeJSON(bodyList, &list); err != nil {
		t.Fatalf("decode file list: %v body=%s", err, string(bodyList))
	}
	if list.Page != 1 {
		t.Fatalf("expected page=1, got %d body=%s", list.Page, string(bodyList))
	}
	if len(list.Files) == 0 || list.Files[0].ID == "" || list.Files[0].ObjectKey == "" {
		t.Fatalf("expected at least one file with id/object_key: body=%s", string(bodyList))
	}

	// delete file（DELETE 依然需要 JSON body：handler 使用 Json extractor）
	respDel, bodyDel, err := c.DoJSON("DELETE", "/api/admin/files/1", map[string]any{}, admin.Token)
	if err != nil {
		t.Fatalf("delete file http error: %v", err)
	}
	if respDel.StatusCode != 200 {
		t.Fatalf("delete file status=%d body=%s", respDel.StatusCode, string(bodyDel))
	}
	var del fileOperationResponse
	if err := testutil.DecodeJSON(bodyDel, &del); err != nil {
		t.Fatalf("decode delete file: %v body=%s", err, string(bodyDel))
	}
	if !del.Success {
		t.Fatalf("expected delete file success=true, body=%s", string(bodyDel))
	}

	// batch delete: empty => success=false
	respBatch1, bodyBatch1, err := c.DoJSON("POST", "/api/admin/files/batch-delete", []string{}, admin.Token)
	if err != nil {
		t.Fatalf("batch delete (empty) http error: %v", err)
	}
	if respBatch1.StatusCode != 200 {
		t.Fatalf("batch delete (empty) status=%d body=%s", respBatch1.StatusCode, string(bodyBatch1))
	}
	var batch1 fileOperationResponse
	if err := testutil.DecodeJSON(bodyBatch1, &batch1); err != nil {
		t.Fatalf("decode batch delete (empty): %v body=%s", err, string(bodyBatch1))
	}
	if batch1.Success {
		t.Fatalf("expected batch delete (empty) success=false, body=%s", string(bodyBatch1))
	}

	// batch delete: ok
	respBatch2, bodyBatch2, err := c.DoJSON("POST", "/api/admin/files/batch-delete", []string{"1", "2"}, admin.Token)
	if err != nil {
		t.Fatalf("batch delete http error: %v", err)
	}
	if respBatch2.StatusCode != 200 {
		t.Fatalf("batch delete status=%d body=%s", respBatch2.StatusCode, string(bodyBatch2))
	}
	var batch2 fileOperationResponse
	if err := testutil.DecodeJSON(bodyBatch2, &batch2); err != nil {
		t.Fatalf("decode batch delete: %v body=%s", err, string(bodyBatch2))
	}
	if !batch2.Success {
		t.Fatalf("expected batch delete success=true, body=%s", string(bodyBatch2))
	}
	if batch2.DeletedCount == nil || *batch2.DeletedCount != 2 {
		t.Fatalf("expected deleted_count=2, got %+v body=%s", batch2.DeletedCount, string(bodyBatch2))
	}
}
