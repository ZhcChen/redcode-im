package uploads_test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type multipartInitiateResp struct {
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

func TestUploads_Multipart_MessageAttachmentFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip multipart upload test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	login2 := testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-multipart-"+time.Now().Format("150405"), []string{user2.ID})

	// 10MB：满足 multipart threshold（>5MB），且 file 类型默认允许更大文件（避免 image 5MB 上限导致无法触发 multipart）
	fileSize := 10 * 1024 * 1024
	respInit, bodyInit, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/multipart/initiate", map[string]any{
		"part_type":    "file",
		"filename":     "big.pdf",
		"content_type": "application/pdf",
		"file_size":    fileSize,
	}, login1.Token)
	if err != nil {
		t.Fatalf("multipart initiate http error: %v", err)
	}
	if respInit.StatusCode != 200 {
		t.Fatalf("multipart initiate status=%d body=%s", respInit.StatusCode, string(bodyInit))
	}
	var init multipartInitiateResp
	if err := testutil.DecodeJSON(bodyInit, &init); err != nil {
		t.Fatalf("decode multipart initiate: %v body=%s", err, string(bodyInit))
	}
	if !init.Success || init.Key == nil || *init.Key == "" || init.SessionID == nil || *init.SessionID == "" {
		t.Fatalf("unexpected multipart initiate resp: %+v body=%s", init, string(bodyInit))
	}
	if init.TotalParts == nil || *init.TotalParts <= 0 || init.PartSize == nil || *init.PartSize <= 0 {
		t.Fatalf("unexpected multipart plan: part_size=%v total_parts=%v body=%s", init.PartSize, init.TotalParts, string(bodyInit))
	}

	// 只有会话创建者可访问
	respForbidden, bodyForbidden, err := c.DoJSON("GET", "/uploads/multipart/sessions/"+*init.SessionID, nil, login2.Token)
	if err != nil {
		t.Fatalf("get session (non-creator) http error: %v", err)
	}
	if respForbidden.StatusCode != 403 {
		t.Fatalf("expected get session (non-creator) status=403, got %d body=%s", respForbidden.StatusCode, string(bodyForbidden))
	}

	// 读取 session
	respGet, bodyGet, err := c.DoJSON("GET", "/uploads/multipart/sessions/"+*init.SessionID, nil, login1.Token)
	if err != nil {
		t.Fatalf("get session http error: %v", err)
	}
	if respGet.StatusCode != 200 {
		t.Fatalf("get session status=%d body=%s", respGet.StatusCode, string(bodyGet))
	}
	var session multipartSessionResp
	if err := testutil.DecodeJSON(bodyGet, &session); err != nil {
		t.Fatalf("decode get session: %v body=%s", err, string(bodyGet))
	}
	if !session.Success || session.Session == nil || session.Session.ObjectKey != *init.Key || session.Session.Status != 0 {
		t.Fatalf("unexpected session resp: %+v body=%s", session, string(bodyGet))
	}

	// part signature + commit
	totalParts := int(*init.TotalParts)
	parts := make([]map[string]any, 0, totalParts)
	for partNum := 1; partNum <= totalParts; partNum++ {
		respSig, bodySig, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/parts/signature", map[string]any{
			"part_number": partNum,
		}, login1.Token)
		if err != nil {
			t.Fatalf("part signature http error: %v", err)
		}
		if respSig.StatusCode != 200 {
			t.Fatalf("part signature status=%d body=%s", respSig.StatusCode, string(bodySig))
		}
		var ps partSignatureResp
		if err := testutil.DecodeJSON(bodySig, &ps); err != nil {
			t.Fatalf("decode part signature: %v body=%s", err, string(bodySig))
		}
		if !ps.Success || ps.Signature == nil || ps.Signature.URL == "" || !strings.Contains(ps.Signature.URL, "uploadId=") {
			t.Fatalf("unexpected part signature resp: %+v body=%s", ps, string(bodySig))
		}
		if !strings.Contains(ps.Signature.URL, fmt.Sprintf("partNumber=%d", partNum)) {
			t.Fatalf("expected partNumber=%d in signature url, got %q", partNum, ps.Signature.URL)
		}

		etag := fmt.Sprintf("etag-%d", partNum)
		respCommit, bodyCommit, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/parts/commit", map[string]any{
			"part_number": partNum,
			"etag":        etag,
		}, login1.Token)
		if err != nil {
			t.Fatalf("part commit http error: %v", err)
		}
		if respCommit.StatusCode != 200 {
			t.Fatalf("part commit status=%d body=%s", respCommit.StatusCode, string(bodyCommit))
		}
		var ok genericOKResp
		if err := testutil.DecodeJSON(bodyCommit, &ok); err != nil {
			t.Fatalf("decode part commit: %v body=%s", err, string(bodyCommit))
		}
		if !ok.Success {
			t.Fatalf("expected part commit success=true, body=%s", string(bodyCommit))
		}

		parts = append(parts, map[string]any{"part_number": partNum, "etag": etag})
	}

	// complete
	respComplete, bodyComplete, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/complete", map[string]any{
		"parts": parts,
	}, login1.Token)
	if err != nil {
		t.Fatalf("complete multipart http error: %v", err)
	}
	if respComplete.StatusCode != 200 {
		t.Fatalf("complete multipart status=%d body=%s", respComplete.StatusCode, string(bodyComplete))
	}
	var done genericOKResp
	if err := testutil.DecodeJSON(bodyComplete, &done); err != nil {
		t.Fatalf("decode complete multipart: %v body=%s", err, string(bodyComplete))
	}
	if !done.Success {
		t.Fatalf("expected complete success=true, body=%s", string(bodyComplete))
	}

	// session 应变更为 completed
	respGet2, bodyGet2, err := c.DoJSON("GET", "/uploads/multipart/sessions/"+*init.SessionID, nil, login1.Token)
	if err != nil {
		t.Fatalf("get session2 http error: %v", err)
	}
	if respGet2.StatusCode != 200 {
		t.Fatalf("get session2 status=%d body=%s", respGet2.StatusCode, string(bodyGet2))
	}
	var session2 multipartSessionResp
	if err := testutil.DecodeJSON(bodyGet2, &session2); err != nil {
		t.Fatalf("decode get session2: %v body=%s", err, string(bodyGet2))
	}
	if !session2.Success || session2.Session == nil || session2.Session.Status != 1 {
		t.Fatalf("expected session status=1 after complete, got %+v body=%s", session2, string(bodyGet2))
	}
	if len(session2.Session.UploadedParts) != totalParts {
		t.Fatalf("expected uploaded_parts size=%d, got %d body=%s", totalParts, len(session2.Session.UploadedParts), string(bodyGet2))
	}

	// complete 后继续签名应失败
	respAfter, _, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/parts/signature", map[string]any{
		"part_number": 1,
	}, login1.Token)
	if err != nil {
		t.Fatalf("part signature after complete http error: %v", err)
	}
	if respAfter.StatusCode == 200 {
		t.Fatalf("expected part signature after complete fail, got status=200")
	}
}

func TestUploads_Multipart_AbortFlow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip multipart abort test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)
	_ = testutil.EnsureDefaultStorageProvider(t, c, admin.Token)

	pass := "Passw0rd!"
	user1 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
	user2 := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)

	login1 := testutil.Login(t, c, user1.Username, pass)
	_ = testutil.Login(t, c, user2.Username, pass)

	roomID := testutil.CreateGroupRoom(t, c, login1.Token, "go-multipart-abort-"+time.Now().Format("150405"), []string{user2.ID})

	// initiate
	respInit, bodyInit, err := c.DoJSON("POST", "/rooms/"+roomID+"/messages/attachments/multipart/initiate", map[string]any{
		"part_type":    "file",
		"filename":     "big.pdf",
		"content_type": "application/pdf",
		"file_size":    10 * 1024 * 1024,
	}, login1.Token)
	if err != nil {
		t.Fatalf("multipart initiate http error: %v", err)
	}
	if respInit.StatusCode != 200 {
		t.Fatalf("multipart initiate status=%d body=%s", respInit.StatusCode, string(bodyInit))
	}
	var init multipartInitiateResp
	if err := testutil.DecodeJSON(bodyInit, &init); err != nil {
		t.Fatalf("decode multipart initiate: %v body=%s", err, string(bodyInit))
	}
	if !init.Success || init.SessionID == nil || *init.SessionID == "" {
		t.Fatalf("unexpected multipart initiate resp: %+v body=%s", init, string(bodyInit))
	}

	// abort
	respAbort, bodyAbort, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/abort", nil, login1.Token)
	if err != nil {
		t.Fatalf("abort multipart http error: %v", err)
	}
	if respAbort.StatusCode != 200 {
		t.Fatalf("abort multipart status=%d body=%s", respAbort.StatusCode, string(bodyAbort))
	}
	var aborted genericOKResp
	if err := testutil.DecodeJSON(bodyAbort, &aborted); err != nil {
		t.Fatalf("decode abort multipart: %v body=%s", err, string(bodyAbort))
	}
	if !aborted.Success {
		t.Fatalf("expected abort success=true, body=%s", string(bodyAbort))
	}

	// session status should be 2
	respGet, bodyGet, err := c.DoJSON("GET", "/uploads/multipart/sessions/"+*init.SessionID, nil, login1.Token)
	if err != nil {
		t.Fatalf("get session http error: %v", err)
	}
	if respGet.StatusCode != 200 {
		t.Fatalf("get session status=%d body=%s", respGet.StatusCode, string(bodyGet))
	}
	var session multipartSessionResp
	if err := testutil.DecodeJSON(bodyGet, &session); err != nil {
		t.Fatalf("decode get session: %v body=%s", err, string(bodyGet))
	}
	if !session.Success || session.Session == nil || session.Session.Status != 2 {
		t.Fatalf("expected session status=2 after abort, got %+v body=%s", session, string(bodyGet))
	}

	// abort 后继续 commit/complete 应失败
	respAfter, _, err := c.DoJSON("POST", "/uploads/multipart/sessions/"+*init.SessionID+"/parts/commit", map[string]any{
		"part_number": 1,
		"etag":        "etag-1",
	}, login1.Token)
	if err != nil {
		t.Fatalf("part commit after abort http error: %v", err)
	}
	if respAfter.StatusCode == 200 {
		t.Fatalf("expected part commit after abort fail, got status=200")
	}
}
