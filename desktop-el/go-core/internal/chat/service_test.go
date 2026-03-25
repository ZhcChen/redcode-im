package chat

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/httpclient"
)

func TestServiceUpdateGroupGlobalMuteBuildsOptionalBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-1/mutes/global" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		body := decodeJSONBody(t, r)
		expected := map[string]any{
			"enabled":          true,
			"reason":           "夜间免打扰",
			"duration_minutes": float64(90),
		}
		if !mapsEqual(body, expected) {
			t.Fatalf("unexpected request body: %+v", body)
		}

		writeOKEnvelope(t, w)
	}))
	defer server.Close()

	service := newTestService(server.URL)
	if _, err := service.UpdateGroupGlobalMute(context.Background(), UpdateGlobalMuteParams{
		RoomID:          "room-1",
		Enabled:         true,
		Reason:          "夜间免打扰",
		DurationMinutes: 90,
	}); err != nil {
		t.Fatalf("update group global mute failed: %v", err)
	}
}

func TestServiceUpdateGroupSettingsOmitsNilFields(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-1/settings" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPatch {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		body := decodeJSONBody(t, r)
		expected := map[string]any{
			"member_can_invite":      true,
			"require_admin_to_add_friends": false,
		}
		if !mapsEqual(body, expected) {
			t.Fatalf("unexpected request body: %+v", body)
		}

		writeOKEnvelope(t, w)
	}))
	defer server.Close()

	memberCanInvite := true
	requireAdmin := false

	service := newTestService(server.URL)
	if _, err := service.UpdateGroupSettings(context.Background(), UpdateGroupSettingsParams{
		RoomID:                   "room-1",
		MemberCanInvite:          &memberCanInvite,
		RequireAdminToAddFriends: &requireAdmin,
	}); err != nil {
		t.Fatalf("update group settings failed: %v", err)
	}
}

func TestServiceGetAttachmentDownloadURLBuildsQuery(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rooms/room-1/messages/attachments/download" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.URL.Query().Get("key"); got != "attachments/demo.png" {
			t.Fatalf("unexpected key query: %s", got)
		}
		if got := r.URL.Query().Get("expires_in_seconds"); got != "600" {
			t.Fatalf("unexpected expires_in_seconds query: %s", got)
		}

		writeOKEnvelope(t, w)
	}))
	defer server.Close()

	service := newTestService(server.URL)
	if _, err := service.GetAttachmentDownloadURL(context.Background(), AttachmentDownloadURLParams{
		RoomID:           "room-1",
		Key:              "attachments/demo.png",
		ExpiresInSeconds: 600,
	}); err != nil {
		t.Fatalf("get attachment download url failed: %v", err)
	}
}

func TestServiceAttachmentSignatureAndMultipartRequestsTrimOptionalFields(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		switch requests {
		case 1:
			if r.URL.Path != "/rooms/room-1/messages/attachments/signature" {
				t.Fatalf("unexpected signature path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected signature method: %s", r.Method)
			}
			body := decodeJSONBody(t, r)
			expected := map[string]any{
				"part_type":    "image",
				"filename":     "demo.png",
				"content_type": "image/png",
				"file_size":    float64(128),
			}
			if !mapsEqual(body, expected) {
				t.Fatalf("unexpected signature body: %+v", body)
			}
		case 2:
			if r.URL.Path != "/rooms/room-1/messages/attachments/multipart/initiate" {
				t.Fatalf("unexpected multipart initiate path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected multipart initiate method: %s", r.Method)
			}
			body := decodeJSONBody(t, r)
			expected := map[string]any{
				"part_type": "video",
				"file_size": float64(2048),
				"hash_value": "abc123",
				"hash_alg": float64(2),
			}
			if !mapsEqual(body, expected) {
				t.Fatalf("unexpected multipart initiate body: %+v", body)
			}
		default:
			t.Fatalf("unexpected request count: %d", requests)
		}

		writeOKEnvelope(t, w)
	}))
	defer server.Close()

	service := newTestService(server.URL)
	if _, err := service.RequestAttachmentSignature(context.Background(), AttachmentSignatureParams{
		RoomID:      "room-1",
		PartType:    "image",
		Filename:    "demo.png",
		ContentType: "image/png",
		FileSize:    128,
	}); err != nil {
		t.Fatalf("request attachment signature failed: %v", err)
	}

	if _, err := service.InitiateAttachmentMultipartUpload(context.Background(), AttachmentMultipartInitiateParams{
		RoomID:    "room-1",
		PartType:  "video",
		FileSize:  2048,
		HashValue: "abc123",
		HashAlg:   2,
	}); err != nil {
		t.Fatalf("initiate attachment multipart upload failed: %v", err)
	}
}

func TestServiceMultipartSessionAndCommitAttachmentRequestsUseExpectedContracts(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		switch requests {
		case 1:
			if r.URL.Path != "/uploads/multipart/sessions/session-1/parts/signature" {
				t.Fatalf("unexpected part signature path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected part signature method: %s", r.Method)
			}
			if body := decodeJSONBody(t, r); !mapsEqual(body, map[string]any{"part_number": float64(3)}) {
				t.Fatalf("unexpected part signature body: %+v", body)
			}
		case 2:
			if r.URL.Path != "/uploads/multipart/sessions/session-1/parts/commit" {
				t.Fatalf("unexpected part commit path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected part commit method: %s", r.Method)
			}
			expected := map[string]any{
				"part_number": float64(3),
				"etag":        "etag-3",
			}
			if body := decodeJSONBody(t, r); !mapsEqual(body, expected) {
				t.Fatalf("unexpected part commit body: %+v", body)
			}
		case 3:
			if r.URL.Path != "/uploads/multipart/sessions/session-1/complete" {
				t.Fatalf("unexpected multipart complete path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected multipart complete method: %s", r.Method)
			}
			body := decodeJSONBody(t, r)
			parts, ok := body["parts"].([]any)
			if !ok || len(parts) != 1 {
				t.Fatalf("unexpected multipart complete body: %+v", body)
			}
		case 4:
			if r.URL.Path != "/uploads/multipart/sessions/session-1/abort" {
				t.Fatalf("unexpected multipart abort path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected multipart abort method: %s", r.Method)
			}
			if body := decodeJSONBody(t, r); !mapsEqual(body, map[string]any{}) {
				t.Fatalf("unexpected multipart abort body: %+v", body)
			}
		case 5:
			if r.URL.Path != "/rooms/room-1/messages/attachments/commit" {
				t.Fatalf("unexpected attachment commit path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPost {
				t.Fatalf("unexpected attachment commit method: %s", r.Method)
			}
			expected := map[string]any{
				"key":        "attachments/demo.png",
				"hash_value": "abc123",
				"hash_alg":   float64(2),
				"file_size":  float64(2048),
			}
			if body := decodeJSONBody(t, r); !mapsEqual(body, expected) {
				t.Fatalf("unexpected attachment commit body: %+v", body)
			}
		default:
			t.Fatalf("unexpected request count: %d", requests)
		}

		writeOKEnvelope(t, w)
	}))
	defer server.Close()

	service := newTestService(server.URL)
	if _, err := service.GenerateMultipartPartSignature(context.Background(), MultipartPartSignatureParams{
		SessionID:  "session-1",
		PartNumber: 3,
	}); err != nil {
		t.Fatalf("generate multipart part signature failed: %v", err)
	}

	if _, err := service.CommitMultipartPart(context.Background(), MultipartPartCommitParams{
		SessionID:  "session-1",
		PartNumber: 3,
		ETag:       "etag-3",
	}); err != nil {
		t.Fatalf("commit multipart part failed: %v", err)
	}

	if _, err := service.CompleteMultipartUpload(context.Background(), MultipartCompleteParams{
		SessionID: "session-1",
		Parts: []MultipartCompletedPart{
			{PartNumber: 3, ETag: "etag-3"},
		},
	}); err != nil {
		t.Fatalf("complete multipart upload failed: %v", err)
	}

	if _, err := service.AbortMultipartUpload(context.Background(), MultipartAbortParams{
		SessionID: "session-1",
	}); err != nil {
		t.Fatalf("abort multipart upload failed: %v", err)
	}

	if _, err := service.CommitAttachmentUpload(context.Background(), AttachmentUploadCommitParams{
		RoomID:    "room-1",
		Key:       "attachments/demo.png",
		HashValue: "abc123",
		HashAlg:   2,
		FileSize:  2048,
	}); err != nil {
		t.Fatalf("commit attachment upload failed: %v", err)
	}
}

func newTestService(baseURL string) *Service {
	return New(httpclient.New(httpclient.Config{BaseURL: baseURL}))
}

func decodeJSONBody(t *testing.T, r *http.Request) map[string]any {
	t.Helper()

	var body map[string]any
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		t.Fatalf("decode request body failed: %v", err)
	}
	if body == nil {
		return map[string]any{}
	}
	return body
}

func writeOKEnvelope(t *testing.T, w http.ResponseWriter) {
	t.Helper()
	if err := json.NewEncoder(w).Encode(map[string]any{
		"success": true,
		"code":    200,
		"message": "ok",
		"data":    map[string]any{},
	}); err != nil {
		t.Fatalf("encode response failed: %v", err)
	}
}

func mapsEqual(left map[string]any, right map[string]any) bool {
	if len(left) != len(right) {
		return false
	}
	for key, rightValue := range right {
		leftValue, ok := left[key]
		if !ok {
			return false
		}
		if !valuesEqual(leftValue, rightValue) {
			return false
		}
	}
	return true
}

func valuesEqual(left any, right any) bool {
	leftJSON, leftErr := json.Marshal(left)
	rightJSON, rightErr := json.Marshal(right)
	if leftErr != nil || rightErr != nil {
		return false
	}
	return string(leftJSON) == string(rightJSON)
}
