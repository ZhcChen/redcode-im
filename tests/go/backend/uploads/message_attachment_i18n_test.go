package uploads_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type apiErrorResponse struct {
	Code          int               `json:"code"`
	MessageKey    string            `json:"message_key"`
	Message       string            `json:"message"`
	MessageParams map[string]string `json:"message_params"`
	Details       *string           `json:"details"`
}

type uploadPolicyPayload struct {
	Version                  string `json:"version"`
	MaxTotalSizeMb           int    `json:"max_total_size_mb"`
	MaxAttachmentsPerMessage int    `json:"max_attachments_per_message"`
	MaxSizeMbByPartType      struct {
		Image int `json:"image"`
		Video int `json:"video"`
		Audio int `json:"audio"`
		File  int `json:"file"`
	} `json:"max_size_mb_by_part_type"`
	MimeByPartType struct {
		Image []string `json:"image"`
		Video []string `json:"video"`
		Audio []string `json:"audio"`
		File  []string `json:"file"`
	} `json:"mime_by_part_type"`
	AudioOnly struct {
		Enabled               bool `json:"enabled"`
		ForceSingleAttachment bool `json:"force_single_attachment"`
		AllowText             bool `json:"allow_text"`
	} `json:"audio_only"`
}

type uploadPolicyAdminEnvelope struct {
	Policy uploadPolicyPayload `json:"policy"`
}

type storageProviderResponse struct {
	ID         string  `json:"id"`
	BucketName *string `json:"bucket_name"`
	IsDefault  bool    `json:"is_default"`
}

func TestMessageAttachmentSignatureTextUnsupported_Localized(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	loginA, _, room := setupUploadTestRoom(t, c)

	req := localizedAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/signature",
		loginA.Token,
		"en-US",
		map[string]any{
			"part_type": "text",
		},
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request attachment signature failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"message.attachment_signature_text_unsupported",
		"Text content does not require an upload signature.",
		nil,
	)
}

func TestMessageAttachmentDownloadMissingAttachment_Localized(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	loginA, _, room := setupUploadTestRoom(t, c)
	key := fmt.Sprintf("messages/%s/files_20260327/missing.bin", room.ID)

	req := localizedAuthedJSONRequest(
		t,
		http.MethodGet,
		c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/download?key="+key,
		loginA.Token,
		"zh-CN",
		nil,
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request attachment download failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedError(
		t,
		resp,
		http.StatusNotFound,
		40401,
		"message.attachment_not_found",
		"附件不存在",
		nil,
	)
}

func TestMessageAttachmentCommitMissingObject_Localized(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	loginA, _, room := setupUploadTestRoom(t, c)
	key := fmt.Sprintf("messages/%s/files_20260327/missing.bin", room.ID)

	req := localizedAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/commit",
		loginA.Token,
		"en-US",
		map[string]any{
			"key":       key,
			"file_size": 128,
		},
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("commit missing attachment failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"message.attachment_object_not_found",
		"Attachment object was not found in storage. Please try again later.",
		nil,
	)
}

func TestMessageAttachmentMultipartSizeLimitPrecedesThreshold_Localized(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	admin := testutil.AdminLogin(t, c)
	originalPolicy := fetchUploadPolicyAdmin(t, c, admin.Token)
	updatedPolicy := originalPolicy
	updatedPolicy.Version = originalPolicy.Version + "-multipart-threshold-order"
	updatedPolicy.MaxSizeMbByPartType.Image = 1

	updateUploadPolicyAdmin(t, c, admin.Token, updatedPolicy)
	t.Cleanup(func() {
		updateUploadPolicyAdmin(t, c, admin.Token, originalPolicy)
	})

	loginA, _, room := setupUploadTestRoom(t, c)

	req := localizedAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/multipart/initiate",
		loginA.Token,
		"en-US",
		map[string]any{
			"part_type":    "image",
			"filename":     "oversize.png",
			"content_type": "image/png",
			"file_size":    2 * 1024 * 1024,
		},
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("initiate multipart upload failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"message.attachment_file_size_exceeded_bytes",
		"Attachment size exceeds the limit: actual 2097152 bytes, maximum allowed 1048576 bytes.",
		map[string]string{
			"actual_size": "2097152",
			"max_size":    "1048576",
		},
	)
}

func TestMessageAttachmentStorageProviderMisconfig_Localized(t *testing.T) {
	c := testutil.NewClient()
	testutil.EnsureDefaultStorageProvider(t, c)

	admin := testutil.AdminLogin(t, c)
	originalProvider := fetchDefaultStorageProvider(t, c, admin.Token)
	misconfiguredProvider := createStorageProvider(t, c, admin.Token, map[string]any{
		"provider_type": "tencent_cos",
		"name":          "mock-cos-misconfigured",
		"secret_id":     "mock-secret-id",
		"secret_key":    "mock-secret-key",
		"region":        "ap-shanghai",
		"endpoint":      "127.0.0.1:1",
		"is_active":     true,
		"is_default":    true,
		"description":   "intentionally missing bucket_name for i18n contract test",
	})
	t.Cleanup(func() {
		patchStorageProvider(t, c, admin.Token, originalProvider.ID, map[string]any{
			"is_default": true,
		})
		deleteStorageProvider(t, c, admin.Token, misconfiguredProvider.ID)
	})
	if misconfiguredProvider.BucketName != nil {
		t.Fatalf("expected misconfigured provider bucket_name to be nil, got %q", *misconfiguredProvider.BucketName)
	}
	currentDefault := fetchDefaultStorageProvider(t, c, admin.Token)
	if currentDefault.ID != misconfiguredProvider.ID || !currentDefault.IsDefault {
		t.Fatalf("misconfigured provider is not the current default: %+v", currentDefault)
	}

	loginA, _, room := setupUploadTestRoom(t, c)

	req := localizedAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/rooms/"+room.ID+"/messages/attachments/signature",
		loginA.Token,
		"en-US",
		map[string]any{
			"part_type":    "image",
			"filename":     "broken.png",
			"content_type": "image/png",
			"file_size":    128,
		},
	)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("request signature with misconfigured provider failed: %v", err)
	}
	defer resp.Body.Close()

	assertLocalizedError(
		t,
		resp,
		http.StatusBadRequest,
		42201,
		"message.default_storage_provider_invalid_config",
		"Default storage provider configuration is invalid. Please contact an administrator.",
		nil,
	)
}

func setupUploadTestRoom(t *testing.T, c *testutil.Client) (testutil.LoginResponse, testutil.LoginResponse, testutil.RoomInfo) {
	t.Helper()

	password := "pass123456"
	userA := testutil.UniqueUsername("upli18na")
	userB := testutil.UniqueUsername("upli18nb")

	loginA := registerAndLogin(t, c, userA, password)
	loginB := registerAndLogin(t, c, userB, password)
	room := testutil.CreateGroupRoom(t, c, loginA.Token, loginB.User.ID, "upload-i18n-room")

	return loginA, loginB, room
}

func localizedAuthedJSONRequest(
	t *testing.T,
	method string,
	url string,
	token string,
	locale string,
	body any,
) *http.Request {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, method, url, token, body)
	req.Header.Set("Accept-Language", locale)
	return req
}

func assertLocalizedError(
	t *testing.T,
	resp *http.Response,
	wantStatus int,
	wantCode int,
	wantKey string,
	wantMessage string,
	wantParams map[string]string,
) {
	t.Helper()

	if resp.StatusCode != wantStatus {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", wantStatus, resp.StatusCode, string(body))
	}

	var payload apiErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode localized error response failed: %v", err)
	}

	if payload.Code != wantCode {
		t.Fatalf("unexpected error code: want %d got %d", wantCode, payload.Code)
	}
	if payload.MessageKey != wantKey {
		t.Fatalf("unexpected message_key: want %s got %s", wantKey, payload.MessageKey)
	}
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: want %q got %q", wantMessage, payload.Message)
	}
	if payload.Details != nil {
		t.Fatalf("expected details to be null, got %q", *payload.Details)
	}

	if len(wantParams) == 0 {
		if payload.MessageParams != nil {
			t.Fatalf("expected nil message_params, got %+v", payload.MessageParams)
		}
		return
	}

	if len(payload.MessageParams) != len(wantParams) {
		t.Fatalf("unexpected message_params size: want %+v got %+v", wantParams, payload.MessageParams)
	}
	for key, wantValue := range wantParams {
		if payload.MessageParams[key] != wantValue {
			t.Fatalf("unexpected message_params[%s]: want %s got %s", key, wantValue, payload.MessageParams[key])
		}
	}
}

func fetchUploadPolicyAdmin(t *testing.T, c *testutil.Client, token string) uploadPolicyPayload {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/settings/upload-policy", token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("get upload policy failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("get upload policy expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload uploadPolicyAdminEnvelope
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode upload policy failed: %v", err)
	}

	return payload.Policy
}

func updateUploadPolicyAdmin(t *testing.T, c *testutil.Client, token string, payload uploadPolicyPayload) {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodPut, c.BaseURL+"/api/admin/settings/upload-policy", token, payload)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("update upload policy failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("update upload policy expect 200, got %d: %s", resp.StatusCode, string(body))
	}
}

func fetchDefaultStorageProvider(t *testing.T, c *testutil.Client, token string) storageProviderResponse {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodGet, c.BaseURL+"/api/admin/storage-providers/default", token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("get default storage provider failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("get default storage provider expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var provider storageProviderResponse
	if err := json.NewDecoder(resp.Body).Decode(&provider); err != nil {
		t.Fatalf("decode default storage provider failed: %v", err)
	}
	return provider
}

func patchStorageProvider(t *testing.T, c *testutil.Client, token string, providerID string, payload map[string]any) {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodPatch, c.BaseURL+"/api/admin/storage-providers/"+providerID, token, payload)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("patch storage provider failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("patch storage provider expect 200, got %d: %s", resp.StatusCode, string(body))
	}
}

func createStorageProvider(t *testing.T, c *testutil.Client, token string, payload map[string]any) storageProviderResponse {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodPost, c.BaseURL+"/api/admin/storage-providers", token, payload)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("create storage provider failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("create storage provider expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var provider storageProviderResponse
	if err := json.NewDecoder(resp.Body).Decode(&provider); err != nil {
		t.Fatalf("decode created storage provider failed: %v", err)
	}
	return provider
}

func deleteStorageProvider(t *testing.T, c *testutil.Client, token string, providerID string) {
	t.Helper()

	req := testutil.NewAuthedJSONRequest(t, http.MethodDelete, c.BaseURL+"/api/admin/storage-providers/"+providerID, token, nil)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("delete storage provider failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("delete storage provider expect 204, got %d: %s", resp.StatusCode, string(body))
	}
}
