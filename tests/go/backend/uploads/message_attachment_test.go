package uploads_test

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestMessageAttachmentUploadCommitSendAndDownload_OK(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	password := "pass123456"
	userA := testutil.UniqueUsername("upla")
	userB := testutil.UniqueUsername("uplb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "upload-room")

	fileContent := []byte("integration-attachment-content")
	hash := md5Hex(fileContent)

	sigReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/signature", loginA.Token, map[string]any{
		"part_type":    "image",
		"filename":     "a.png",
		"content_type": "image/png",
		"file_size":    len(fileContent),
		"hash_value":   hash,
		"hash_alg":     1,
	})
	sigResp, err := c.HTTP.Do(sigReq)
	if err != nil {
		t.Fatalf("request signature failed: %v", err)
	}
	defer sigResp.Body.Close()
	if sigResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sigResp.Body)
		t.Fatalf("request signature expect 200, got %d: %s", sigResp.StatusCode, string(body))
	}

	var sigResult struct {
		Key       string `json:"key"`
		Signature struct {
			URL     string            `json:"url"`
			Method  string            `json:"method"`
			Headers map[string]string `json:"headers"`
			Key     string            `json:"key"`
		} `json:"signature"`
	}
	if err := json.NewDecoder(sigResp.Body).Decode(&sigResult); err != nil {
		t.Fatalf("decode signature response failed: %v", err)
	}
	if sigResult.Key == "" || sigResult.Signature.URL == "" {
		t.Fatalf("invalid signature response: %+v", sigResult)
	}

	uploadReq, err := http.NewRequest(strings.ToUpper(sigResult.Signature.Method), sigResult.Signature.URL, strings.NewReader(string(fileContent)))
	if err != nil {
		t.Fatalf("build upload request failed: %v", err)
	}
	for k, v := range sigResult.Signature.Headers {
		uploadReq.Header.Set(k, v)
	}
	uploadResp, err := c.HTTP.Do(uploadReq)
	if err != nil {
		t.Fatalf("upload file failed: %v", err)
	}
	uploadResp.Body.Close()
	if uploadResp.StatusCode != http.StatusOK {
		t.Fatalf("upload file expect 200, got %d", uploadResp.StatusCode)
	}

	commitReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/commit", loginA.Token, map[string]any{
		"key":        sigResult.Key,
		"file_size":  len(fileContent),
		"hash_value": hash,
		"hash_alg":   1,
	})
	commitResp, err := c.HTTP.Do(commitReq)
	if err != nil {
		t.Fatalf("commit upload failed: %v", err)
	}
	defer commitResp.Body.Close()
	if commitResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(commitResp.Body)
		t.Fatalf("commit upload expect 200, got %d: %s", commitResp.StatusCode, string(body))
	}

	sendReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/rooms/"+room.ID+"/messages", loginA.Token, map[string]any{
		"parts": []map[string]any{
			{
				"type": "image",
				"key":  sigResult.Key,
				"name": "a.png",
				"mime": "image/png",
				"size": len(fileContent),
			},
		},
	})
	sendResp, err := c.HTTP.Do(sendReq)
	if err != nil {
		t.Fatalf("send attachment message failed: %v", err)
	}
	defer sendResp.Body.Close()
	if sendResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(sendResp.Body)
		t.Fatalf("send attachment message expect 200, got %d: %s", sendResp.StatusCode, string(body))
	}

	downloadReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/download?key="+url.QueryEscape(sigResult.Key), loginA.Token, nil)
	downloadResp, err := c.HTTP.Do(downloadReq)
	if err != nil {
		t.Fatalf("get download url failed: %v", err)
	}
	defer downloadResp.Body.Close()
	if downloadResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(downloadResp.Body)
		t.Fatalf("download url expect 200, got %d: %s", downloadResp.StatusCode, string(body))
	}

	var downloadResult struct {
		DownloadURL string `json:"download_url"`
	}
	if err := json.NewDecoder(downloadResp.Body).Decode(&downloadResult); err != nil {
		t.Fatalf("decode download url response failed: %v", err)
	}
	if downloadResult.DownloadURL == "" {
		t.Fatalf("download_url is empty")
	}

	fetchResp, err := c.HTTP.Get(downloadResult.DownloadURL)
	if err != nil {
		t.Fatalf("fetch download url failed: %v", err)
	}
	defer fetchResp.Body.Close()
	if fetchResp.StatusCode != http.StatusOK {
		t.Fatalf("fetch download url expect 200, got %d", fetchResp.StatusCode)
	}
	data, _ := io.ReadAll(fetchResp.Body)
	if string(data) != string(fileContent) {
		t.Fatalf("downloaded content mismatch")
	}
}

func registerAndLogin(t *testing.T, c *testutil.Client, username, password string) testutil.LoginResponse {
	t.Helper()
	testutil.RegisterUser(t, c, username, password)
	return testutil.LoginWithPassword(t, c, username, password)
}

func md5Hex(data []byte) string {
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}
