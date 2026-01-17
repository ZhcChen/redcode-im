package versions_test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type versionMultipartInitiateResp struct {
	Success    bool    `json:"success"`
	Message    string  `json:"message"`
	Key        *string `json:"key"`
	SessionID  *string `json:"session_id"`
	PartSize   *int32  `json:"part_size"`
	TotalParts *int32  `json:"total_parts"`
}

type multipartSessionResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Session *struct {
		SessionID     string            `json:"session_id"`
		ObjectKey     string            `json:"object_key"`
		PartSize      int32             `json:"part_size"`
		TotalParts    int32             `json:"total_parts"`
		Status        int16             `json:"status"`
		UploadedParts map[string]string `json:"uploaded_parts"`
	} `json:"session"`
}

type partSignatureResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Signature *struct {
		URL     string            `json:"url"`
		Method  string            `json:"method"`
		Headers map[string]string `json:"headers"`
		Key     string            `json:"key"`
	} `json:"signature"`
}

type genericOKResp struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestVersions_AdminMultipartUpload_SessionFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip version multipart test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// multipart 依赖默认存储提供商（测试栈会跳过真实 COS 网络读写）
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	platform := "android"
	channel := "stable"
	filename := "app-" + time.Now().Format("150405") + ".apk"

	respInit, bodyInit, err := c.DoJSON("POST", "/api/admin/app-versions/upload/multipart/initiate", map[string]any{
		"platform":     platform,
		"channel":      channel,
		"filename":     filename,
		"content_type": "application/octet-stream",
		"file_size":    10 * 1024 * 1024,
	}, admin.Token)
	if err != nil {
		t.Fatalf("version multipart initiate http error: %v", err)
	}
	if respInit.StatusCode != 200 {
		t.Fatalf("version multipart initiate status=%d body=%s", respInit.StatusCode, string(bodyInit))
	}
	var init versionMultipartInitiateResp
	if err := testutil.DecodeJSON(bodyInit, &init); err != nil {
		t.Fatalf("decode version multipart initiate: %v body=%s", err, string(bodyInit))
	}
	if !init.Success || init.Key == nil || *init.Key == "" || init.SessionID == nil || *init.SessionID == "" {
		t.Fatalf("unexpected version multipart initiate resp: %+v body=%s", init, string(bodyInit))
	}

	// user 端不可访问 admin 创建的 session（creator_is_admin 不匹配）
	u := testutil.RegisterUser(t, c, testutil.UniquePhone(), "Passw0rd!")
	userLogin := testutil.Login(t, c, u.Username, "Passw0rd!")
	respUser, bodyUser, err := c.DoJSON("GET", "/uploads/multipart/sessions/"+*init.SessionID, nil, userLogin.Token)
	if err != nil {
		t.Fatalf("get session via user route http error: %v", err)
	}
	if respUser.StatusCode != 403 {
		t.Fatalf("expected user route get session status=403, got %d body=%s", respUser.StatusCode, string(bodyUser))
	}

	// admin session endpoints
	respGet, bodyGet, err := c.DoJSON("GET", "/api/admin/uploads/multipart/sessions/"+*init.SessionID, nil, admin.Token)
	if err != nil {
		t.Fatalf("admin get session http error: %v", err)
	}
	if respGet.StatusCode != 200 {
		t.Fatalf("admin get session status=%d body=%s", respGet.StatusCode, string(bodyGet))
	}
	var session multipartSessionResp
	if err := testutil.DecodeJSON(bodyGet, &session); err != nil {
		t.Fatalf("decode admin get session: %v body=%s", err, string(bodyGet))
	}
	if !session.Success || session.Session == nil || session.Session.ObjectKey != *init.Key || session.Session.Status != 0 {
		t.Fatalf("unexpected admin session resp: %+v body=%s", session, string(bodyGet))
	}

	totalParts := 1
	if init.TotalParts != nil && *init.TotalParts > 0 {
		totalParts = int(*init.TotalParts)
	}

	parts := make([]map[string]any, 0, totalParts)
	for partNum := 1; partNum <= totalParts; partNum++ {
		respSig, bodySig, err := c.DoJSON("POST", "/api/admin/uploads/multipart/sessions/"+*init.SessionID+"/parts/signature", map[string]any{
			"part_number": partNum,
		}, admin.Token)
		if err != nil {
			t.Fatalf("admin part signature http error: %v", err)
		}
		if respSig.StatusCode != 200 {
			t.Fatalf("admin part signature status=%d body=%s", respSig.StatusCode, string(bodySig))
		}
		var ps partSignatureResp
		if err := testutil.DecodeJSON(bodySig, &ps); err != nil {
			t.Fatalf("decode admin part signature: %v body=%s", err, string(bodySig))
		}
		if !ps.Success || ps.Signature == nil || ps.Signature.URL == "" || !strings.Contains(ps.Signature.URL, "uploadId=") {
			t.Fatalf("unexpected admin part signature resp: %+v body=%s", ps, string(bodySig))
		}

		etag := fmt.Sprintf("etag-%d", partNum)
		respCommit, bodyCommit, err := c.DoJSON("POST", "/api/admin/uploads/multipart/sessions/"+*init.SessionID+"/parts/commit", map[string]any{
			"part_number": partNum,
			"etag":        etag,
		}, admin.Token)
		if err != nil {
			t.Fatalf("admin part commit http error: %v", err)
		}
		if respCommit.StatusCode != 200 {
			t.Fatalf("admin part commit status=%d body=%s", respCommit.StatusCode, string(bodyCommit))
		}
		var ok genericOKResp
		if err := testutil.DecodeJSON(bodyCommit, &ok); err != nil {
			t.Fatalf("decode admin part commit: %v body=%s", err, string(bodyCommit))
		}
		if !ok.Success {
			t.Fatalf("expected admin part commit success=true, body=%s", string(bodyCommit))
		}

		parts = append(parts, map[string]any{"part_number": partNum, "etag": etag})
	}

	respComplete, bodyComplete, err := c.DoJSON("POST", "/api/admin/uploads/multipart/sessions/"+*init.SessionID+"/complete", map[string]any{
		"parts": parts,
	}, admin.Token)
	if err != nil {
		t.Fatalf("admin complete multipart http error: %v", err)
	}
	if respComplete.StatusCode != 200 {
		t.Fatalf("admin complete multipart status=%d body=%s", respComplete.StatusCode, string(bodyComplete))
	}
	var done genericOKResp
	if err := testutil.DecodeJSON(bodyComplete, &done); err != nil {
		t.Fatalf("decode admin complete multipart: %v body=%s", err, string(bodyComplete))
	}
	if !done.Success {
		t.Fatalf("expected admin complete success=true, body=%s", string(bodyComplete))
	}

	respGet2, bodyGet2, err := c.DoJSON("GET", "/api/admin/uploads/multipart/sessions/"+*init.SessionID, nil, admin.Token)
	if err != nil {
		t.Fatalf("admin get session2 http error: %v", err)
	}
	if respGet2.StatusCode != 200 {
		t.Fatalf("admin get session2 status=%d body=%s", respGet2.StatusCode, string(bodyGet2))
	}
	var session2 multipartSessionResp
	if err := testutil.DecodeJSON(bodyGet2, &session2); err != nil {
		t.Fatalf("decode admin get session2: %v body=%s", err, string(bodyGet2))
	}
	if !session2.Success || session2.Session == nil || session2.Session.Status != 1 {
		t.Fatalf("expected admin session status=1 after complete, got %+v body=%s", session2, string(bodyGet2))
	}
}

