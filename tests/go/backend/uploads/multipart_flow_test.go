package uploads_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type multipartInitiateResponse struct {
	Success    bool   `json:"success"`
	Message    string `json:"message"`
	Key        string `json:"key"`
	SessionID  string `json:"session_id"`
	PartSize   int    `json:"part_size"`
	TotalParts int    `json:"total_parts"`
}

type multipartSessionResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Session struct {
		SessionID     string         `json:"session_id"`
		ObjectKey     string         `json:"object_key"`
		PartSize      int            `json:"part_size"`
		TotalParts    int            `json:"total_parts"`
		Status        int            `json:"status"`
		UploadedParts map[string]any `json:"uploaded_parts"`
	} `json:"session"`
}

type multipartPartSignatureResponse struct {
	Success   bool   `json:"success"`
	Message   string `json:"message"`
	Signature struct {
		URL     string            `json:"url"`
		Method  string            `json:"method"`
		Headers map[string]string `json:"headers"`
	} `json:"signature"`
}

type multipartPartCommitResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type multipartCompleteResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func TestMessageAttachmentMultipartUploadAndDownload_OK(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	password := "pass123456"
	userA := testutil.UniqueUsername("mulpa")
	userB := testutil.UniqueUsername("mulpb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "multipart-room")

	fileContent := make([]byte, 9*1024*1024+333)
	for i := range fileContent {
		fileContent[i] = byte((i*31 + 7) % 251)
	}

	initReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/multipart/initiate", loginA.Token, map[string]any{
		"part_type":    "file",
		"filename":     "multipart.pdf",
		"content_type": "application/pdf",
		"file_size":    len(fileContent),
	})
	initResp, err := c.HTTP.Do(initReq)
	if err != nil {
		t.Fatalf("initiate multipart upload failed: %v", err)
	}
	defer initResp.Body.Close()
	if initResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(initResp.Body)
		t.Fatalf("initiate multipart upload expect 200, got %d: %s", initResp.StatusCode, string(body))
	}

	var initPayload multipartInitiateResponse
	if err := json.NewDecoder(initResp.Body).Decode(&initPayload); err != nil {
		t.Fatalf("decode initiate multipart response failed: %v", err)
	}
	if !initPayload.Success || strings.TrimSpace(initPayload.Key) == "" || strings.TrimSpace(initPayload.SessionID) == "" {
		t.Fatalf("invalid initiate multipart payload: %+v", initPayload)
	}
	if initPayload.PartSize <= 0 || initPayload.TotalParts < 2 {
		t.Fatalf("multipart plan should contain at least 2 parts, got part_size=%d total_parts=%d", initPayload.PartSize, initPayload.TotalParts)
	}

	sessionPayload := getMultipartSession(t, c, loginA.Token, initPayload.SessionID)
	if sessionPayload.Session.ObjectKey != initPayload.Key {
		t.Fatalf("session object key mismatch: expect %s, got %s", initPayload.Key, sessionPayload.Session.ObjectKey)
	}

	partsForComplete := make([]map[string]any, 0, initPayload.TotalParts)
	for partNumber := 1; partNumber <= initPayload.TotalParts; partNumber++ {
		signatureResp := requestMultipartPartSignature(t, c, loginA.Token, initPayload.SessionID, partNumber)
		if !signatureResp.Success || strings.TrimSpace(signatureResp.Signature.URL) == "" {
			t.Fatalf("invalid multipart part signature for part=%d: %+v", partNumber, signatureResp)
		}

		start := (partNumber - 1) * initPayload.PartSize
		end := start + initPayload.PartSize
		if end > len(fileContent) {
			end = len(fileContent)
		}
		partBytes := fileContent[start:end]

		uploadReq, err := http.NewRequest(strings.ToUpper(signatureResp.Signature.Method), signatureResp.Signature.URL, bytes.NewReader(partBytes))
		if err != nil {
			t.Fatalf("build multipart upload request failed: %v", err)
		}
		for k, v := range signatureResp.Signature.Headers {
			uploadReq.Header.Set(k, v)
		}

		uploadResp, err := c.HTTP.Do(uploadReq)
		if err != nil {
			t.Fatalf("upload multipart part failed: %v", err)
		}
		uploadResp.Body.Close()
		if uploadResp.StatusCode != http.StatusOK {
			t.Fatalf("upload multipart part expect 200, got %d", uploadResp.StatusCode)
		}

		eTag := strings.Trim(uploadResp.Header.Get("ETag"), "\" ")
		if eTag == "" {
			t.Fatalf("multipart upload response missing etag for part=%d", partNumber)
		}

		commitResp := commitMultipartPart(t, c, loginA.Token, initPayload.SessionID, partNumber, eTag)
		if !commitResp.Success {
			t.Fatalf("multipart part commit failed for part=%d: %+v", partNumber, commitResp)
		}

		partsForComplete = append(partsForComplete, map[string]any{
			"part_number": partNumber,
			"etag":        eTag,
		})
	}

	sessionAfterCommit := getMultipartSession(t, c, loginA.Token, initPayload.SessionID)
	if len(sessionAfterCommit.Session.UploadedParts) < initPayload.TotalParts {
		t.Fatalf("multipart uploaded_parts should contain %d items, got %d", initPayload.TotalParts, len(sessionAfterCommit.Session.UploadedParts))
	}

	completeReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/uploads/multipart/sessions/"+initPayload.SessionID+"/complete", loginA.Token, map[string]any{
		"parts": partsForComplete,
	})
	completeResp, err := c.HTTP.Do(completeReq)
	if err != nil {
		t.Fatalf("complete multipart upload failed: %v", err)
	}
	defer completeResp.Body.Close()
	if completeResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(completeResp.Body)
		t.Fatalf("complete multipart upload expect 200, got %d: %s", completeResp.StatusCode, string(body))
	}
	var completePayload multipartCompleteResponse
	if err := json.NewDecoder(completeResp.Body).Decode(&completePayload); err != nil {
		t.Fatalf("decode complete multipart response failed: %v", err)
	}
	if !completePayload.Success {
		t.Fatalf("complete multipart payload success=false: %+v", completePayload)
	}

	attachmentCommitReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/commit", loginA.Token, map[string]any{
		"key":       initPayload.Key,
		"file_size": len(fileContent),
	})
	attachmentCommitResp, err := c.HTTP.Do(attachmentCommitReq)
	if err != nil {
		t.Fatalf("message attachment commit after multipart failed: %v", err)
	}
	defer attachmentCommitResp.Body.Close()
	if attachmentCommitResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(attachmentCommitResp.Body)
		t.Fatalf("message attachment commit expect 200, got %d: %s", attachmentCommitResp.StatusCode, string(body))
	}

	sendReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages", loginA.Token, map[string]any{
		"parts": []map[string]any{
			{
				"type": "file",
				"key":  initPayload.Key,
				"name": "multipart.pdf",
				"mime": "application/pdf",
				"size": len(fileContent),
			},
		},
	})
	sendResp, err := c.HTTP.Do(sendReq)
	if err != nil {
		t.Fatalf("send multipart attachment message failed: %v", err)
	}
	defer sendResp.Body.Close()
	if sendResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sendResp.Body)
		t.Fatalf("send multipart attachment message expect 200, got %d: %s", sendResp.StatusCode, string(body))
	}

	downloadReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/download?key="+url.QueryEscape(initPayload.Key), loginA.Token, nil)
	downloadResp, err := c.HTTP.Do(downloadReq)
	if err != nil {
		t.Fatalf("request multipart attachment download url failed: %v", err)
	}
	defer downloadResp.Body.Close()
	if downloadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(downloadResp.Body)
		t.Fatalf("multipart attachment download url expect 200, got %d: %s", downloadResp.StatusCode, string(body))
	}

	var downloadPayload struct {
		Success     bool   `json:"success"`
		DownloadURL string `json:"download_url"`
	}
	if err := json.NewDecoder(downloadResp.Body).Decode(&downloadPayload); err != nil {
		t.Fatalf("decode multipart attachment download response failed: %v", err)
	}
	if !downloadPayload.Success || strings.TrimSpace(downloadPayload.DownloadURL) == "" {
		t.Fatalf("invalid multipart attachment download response: %+v", downloadPayload)
	}

	fetchResp, err := c.HTTP.Get(downloadPayload.DownloadURL)
	if err != nil {
		t.Fatalf("fetch multipart attachment failed: %v", err)
	}
	defer fetchResp.Body.Close()
	if fetchResp.StatusCode != http.StatusOK {
		t.Fatalf("fetch multipart attachment expect 200, got %d", fetchResp.StatusCode)
	}
	fetched, _ := io.ReadAll(fetchResp.Body)
	if len(fetched) != len(fileContent) {
		t.Fatalf("multipart attachment length mismatch: expect %d, got %d", len(fileContent), len(fetched))
	}
	if !bytes.Equal(fetched, fileContent) {
		t.Fatalf("multipart attachment content mismatch")
	}
}

func getMultipartSession(t *testing.T, c *testutil.Client, token, sessionID string) multipartSessionResponse {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/uploads/multipart/sessions/"+sessionID, token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("get multipart session failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("get multipart session expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload multipartSessionResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode multipart session response failed: %v", err)
	}
	if !payload.Success {
		t.Fatalf("multipart session success=false: %+v", payload)
	}
	return payload
}

func requestMultipartPartSignature(t *testing.T, c *testutil.Client, token, sessionID string, partNumber int) multipartPartSignatureResponse {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/uploads/multipart/sessions/"+sessionID+"/parts/signature", token, map[string]any{
		"part_number": partNumber,
	})
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request multipart part signature failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("request multipart part signature expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload multipartPartSignatureResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode multipart part signature failed: %v", err)
	}
	return payload
}

func commitMultipartPart(t *testing.T, c *testutil.Client, token, sessionID string, partNumber int, eTag string) multipartPartCommitResponse {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/uploads/multipart/sessions/"+sessionID+"/parts/commit", token, map[string]any{
		"part_number": partNumber,
		"etag":        eTag,
	})
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("commit multipart part failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("commit multipart part expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload multipartPartCommitResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode multipart part commit response failed: %v", err)
	}
	if !payload.Success {
		t.Fatalf("multipart part commit success=false for part=%s", strconv.Itoa(partNumber))
	}
	return payload
}
