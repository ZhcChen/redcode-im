package users_test

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type avatarDirectUploadResponse struct {
	Success   bool   `json:"success"`
	Message   string `json:"message"`
	Key       string `json:"key"`
	Signature struct {
		URL     string            `json:"url"`
		Method  string            `json:"method"`
		Headers map[string]string `json:"headers"`
	} `json:"signature"`
}

type avatarCommitResponse struct {
	Success     bool   `json:"success"`
	Message     string `json:"message"`
	DownloadURL string `json:"download_url"`
}

func TestUserAvatarDirectUploadCommitAndDownload_OK(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	username := testutil.UniqueEmail("avatar")
	password := "pass123456"
	login := registerAndLogin(t, c, username, password)

	invalidCommitReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/users/me/avatar/commit", login.Token, map[string]any{
		"key": "avatars/other-user/forbidden.png",
	})
	invalidCommitResp, err := c.HTTP.Do(invalidCommitReq)
	if err != nil {
		t.Fatalf("invalid avatar commit failed: %v", err)
	}
	defer invalidCommitResp.Body.Close()
	if invalidCommitResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(invalidCommitResp.Body)
		t.Fatalf("invalid avatar commit expect 200, got %d: %s", invalidCommitResp.StatusCode, string(body))
	}
	var invalidCommit avatarCommitResponse
	if err := json.NewDecoder(invalidCommitResp.Body).Decode(&invalidCommit); err != nil {
		t.Fatalf("decode invalid avatar commit response failed: %v", err)
	}
	if invalidCommit.Success {
		t.Fatalf("invalid avatar commit should fail, got %+v", invalidCommit)
	}
	if !strings.Contains(invalidCommit.Message, "文件路径不合法") {
		t.Fatalf("invalid avatar commit message mismatch: %q", invalidCommit.Message)
	}

	fileContent := []byte("avatar-image-content-20260305")
	hash := md5Hex(fileContent)

	directReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/users/me/avatar/direct-upload", login.Token, map[string]any{
		"content_type": "image/png",
		"file_size":    len(fileContent),
		"hash_value":   hash,
		"hash_alg":     1,
	})
	directResp, err := c.HTTP.Do(directReq)
	if err != nil {
		t.Fatalf("avatar direct-upload request failed: %v", err)
	}
	defer directResp.Body.Close()
	if directResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(directResp.Body)
		t.Fatalf("avatar direct-upload expect 200, got %d: %s", directResp.StatusCode, string(body))
	}
	var directPayload avatarDirectUploadResponse
	if err := json.NewDecoder(directResp.Body).Decode(&directPayload); err != nil {
		t.Fatalf("decode avatar direct-upload response failed: %v", err)
	}
	if !directPayload.Success || directPayload.Key == "" || directPayload.Signature.URL == "" {
		t.Fatalf("invalid avatar direct-upload response: %+v", directPayload)
	}

	uploadReq, err := http.NewRequest(strings.ToUpper(directPayload.Signature.Method), directPayload.Signature.URL, strings.NewReader(string(fileContent)))
	if err != nil {
		t.Fatalf("build avatar upload request failed: %v", err)
	}
	for k, v := range directPayload.Signature.Headers {
		uploadReq.Header.Set(k, v)
	}
	uploadResp, err := c.HTTP.Do(uploadReq)
	if err != nil {
		t.Fatalf("avatar upload failed: %v", err)
	}
	uploadResp.Body.Close()
	if uploadResp.StatusCode != http.StatusOK {
		t.Fatalf("avatar upload expect 200, got %d", uploadResp.StatusCode)
	}

	commitReq := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/users/me/avatar/commit", login.Token, map[string]any{
		"key": directPayload.Key,
	})
	commitResp, err := c.HTTP.Do(commitReq)
	if err != nil {
		t.Fatalf("avatar commit request failed: %v", err)
	}
	defer commitResp.Body.Close()
	if commitResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(commitResp.Body)
		t.Fatalf("avatar commit expect 200, got %d: %s", commitResp.StatusCode, string(body))
	}
	var commitPayload avatarCommitResponse
	if err := json.NewDecoder(commitResp.Body).Decode(&commitPayload); err != nil {
		t.Fatalf("decode avatar commit response failed: %v", err)
	}
	if !commitPayload.Success || strings.TrimSpace(commitPayload.DownloadURL) == "" {
		t.Fatalf("invalid avatar commit response: %+v", commitPayload)
	}

	meReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/auth/me", login.Token, nil)
	meResp, err := c.HTTP.Do(meReq)
	if err != nil {
		t.Fatalf("request /auth/me failed: %v", err)
	}
	defer meResp.Body.Close()
	if meResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(meResp.Body)
		t.Fatalf("/auth/me expect 200, got %d: %s", meResp.StatusCode, string(body))
	}
	var mePayload struct {
		AvatarObjectKey *string `json:"avatar_object_key"`
	}
	if err := json.NewDecoder(meResp.Body).Decode(&mePayload); err != nil {
		t.Fatalf("decode /auth/me response failed: %v", err)
	}
	if mePayload.AvatarObjectKey == nil || *mePayload.AvatarObjectKey != directPayload.Key {
		t.Fatalf("avatar_object_key mismatch: expect %q, got %v", directPayload.Key, mePayload.AvatarObjectKey)
	}

	avatarURLReq := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/users/me/avatar/url", login.Token, nil)
	avatarURLResp, err := c.HTTP.Do(avatarURLReq)
	if err != nil {
		t.Fatalf("get /users/me/avatar/url failed: %v", err)
	}
	defer avatarURLResp.Body.Close()
	if avatarURLResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(avatarURLResp.Body)
		t.Fatalf("get /users/me/avatar/url expect 200, got %d: %s", avatarURLResp.StatusCode, string(body))
	}
	var avatarURLPayload avatarCommitResponse
	if err := json.NewDecoder(avatarURLResp.Body).Decode(&avatarURLPayload); err != nil {
		t.Fatalf("decode /users/me/avatar/url response failed: %v", err)
	}
	if !avatarURLPayload.Success || strings.TrimSpace(avatarURLPayload.DownloadURL) == "" {
		t.Fatalf("invalid /users/me/avatar/url response: %+v", avatarURLPayload)
	}

	downloadResp, err := c.HTTP.Get(avatarURLPayload.DownloadURL)
	if err != nil {
		t.Fatalf("download avatar failed: %v", err)
	}
	defer downloadResp.Body.Close()
	if downloadResp.StatusCode != http.StatusOK {
		t.Fatalf("download avatar expect 200, got %d", downloadResp.StatusCode)
	}
	downloaded, _ := io.ReadAll(downloadResp.Body)
	if string(downloaded) != string(fileContent) {
		t.Fatalf("downloaded avatar content mismatch")
	}
}

func md5Hex(data []byte) string {
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}
