package upload_policy

import (
	"os"
	"testing"
	"time"
)

type uploadPolicyMaxSizeMbByPartType struct {
	Image int `json:"image"`
	Video int `json:"video"`
	Audio int `json:"audio"`
	File  int `json:"file"`
}

type uploadPolicyMimeByPartType struct {
	Image []string `json:"image"`
	Video []string `json:"video"`
	Audio []string `json:"audio"`
	File  []string `json:"file"`
}

type audioOnlyPolicy struct {
	Enabled               bool `json:"enabled"`
	ForceSingleAttachment bool `json:"force_single_attachment"`
	AllowText             bool `json:"allow_text"`
}

type uploadPolicyUserResponse struct {
	Version                 string                      `json:"version"`
	MaxTotalSizeMb          int                         `json:"max_total_size_mb"`
	MaxAttachmentsPerMessage int                        `json:"max_attachments_per_message"`
	MaxSizeMbByPartType     uploadPolicyMaxSizeMbByPartType `json:"max_size_mb_by_part_type"`
	MimeByPartType          uploadPolicyMimeByPartType  `json:"mime_by_part_type"`
	MimeWhitelist           []string                    `json:"mime_whitelist"`
	AudioOnly               audioOnlyPolicy             `json:"audio_only"`
}

type uploadPolicyAdminResponse struct {
	Policy    uploadPolicyUserResponse `json:"policy"`
	UpdatedAt *string                  `json:"updated_at"`
	UpdatedBy *string                  `json:"updated_by"`
}

type updateUploadPolicyRequest struct {
	Version                 string                      `json:"version"`
	MaxTotalSizeMb          int                         `json:"max_total_size_mb"`
	MaxAttachmentsPerMessage int                        `json:"max_attachments_per_message"`
	MaxSizeMbByPartType     uploadPolicyMaxSizeMbByPartType `json:"max_size_mb_by_part_type"`
	MimeByPartType          uploadPolicyMimeByPartType  `json:"mime_by_part_type"`
	AudioOnly               audioOnlyPolicy             `json:"audio_only"`
}

func TestUploadPolicy_UserEndpoint_ReturnsPolicy(t *testing.T) {
	c := NewClient()
	pass := "Passw0rd!"

	user := registerUser(t, c, uniquePhone(), pass)
	loginRes := login(t, c, user.Username, pass)

	resp, body, err := c.DoJSON("GET", "/system/upload-policy", nil, loginRes.Token)
	if err != nil {
		t.Fatalf("get upload policy http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get upload policy status=%d body=%s", resp.StatusCode, string(body))
	}

	var policy uploadPolicyUserResponse
	if err := Decode(body, &policy); err != nil {
		t.Fatalf("decode upload policy: %v body=%s", err, string(body))
	}

	if policy.Version == "" {
		t.Fatalf("expected version, got empty: body=%s", string(body))
	}
	if policy.MaxTotalSizeMb <= 0 {
		t.Fatalf("expected max_total_size_mb > 0, got %d", policy.MaxTotalSizeMb)
	}
	if policy.MaxAttachmentsPerMessage < 0 {
		t.Fatalf("expected max_attachments_per_message >= 0, got %d", policy.MaxAttachmentsPerMessage)
	}
	if policy.MaxSizeMbByPartType.Image <= 0 ||
		policy.MaxSizeMbByPartType.Video <= 0 ||
		policy.MaxSizeMbByPartType.Audio <= 0 ||
		policy.MaxSizeMbByPartType.File <= 0 {
		t.Fatalf("expected max_size_mb_by_part_type all >0, got %+v", policy.MaxSizeMbByPartType)
	}
	if len(policy.MimeWhitelist) == 0 {
		t.Fatalf("expected mime_whitelist non-empty")
	}
}

func TestUploadPolicy_AdminUpdate_PropagatesToUser(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin update test")
	}

	c := NewClient()
	admin := adminLogin(t, c, adminUser, adminPass)

	// 读取当前策略（用于回滚）
	resp, body, err := c.DoJSON("GET", "/api/admin/settings/upload-policy", nil, admin.Token)
	if err != nil {
		t.Fatalf("get admin upload policy http error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("get admin upload policy status=%d body=%s", resp.StatusCode, string(body))
	}
	var original uploadPolicyAdminResponse
	if err := Decode(body, &original); err != nil {
		t.Fatalf("decode admin upload policy: %v body=%s", err, string(body))
	}

	newVersion := "go-test-" + time.Now().Format("20060102150405.000000000")

	restorePayload := updateUploadPolicyRequest{
		Version:                 original.Policy.Version,
		MaxTotalSizeMb:          original.Policy.MaxTotalSizeMb,
		MaxAttachmentsPerMessage: original.Policy.MaxAttachmentsPerMessage,
		MaxSizeMbByPartType:     original.Policy.MaxSizeMbByPartType,
		MimeByPartType:          original.Policy.MimeByPartType,
		AudioOnly:               original.Policy.AudioOnly,
	}

	t.Cleanup(func() {
		// 回滚到原值（尽力而为，不阻断用例）
		_, _, _ = c.DoJSON("PUT", "/api/admin/settings/upload-policy", restorePayload, admin.Token)
	})

	updatePayload := restorePayload
	updatePayload.Version = newVersion

	resp2, body2, err := c.DoJSON("PUT", "/api/admin/settings/upload-policy", updatePayload, admin.Token)
	if err != nil {
		t.Fatalf("update admin upload policy http error: %v", err)
	}
	if resp2.StatusCode != 200 {
		t.Fatalf("update admin upload policy status=%d body=%s", resp2.StatusCode, string(body2))
	}

	// 用普通用户验证策略已生效
	pass := "Passw0rd!"
	user := registerUser(t, c, uniquePhone(), pass)
	loginRes := login(t, c, user.Username, pass)

	resp3, body3, err := c.DoJSON("GET", "/system/upload-policy", nil, loginRes.Token)
	if err != nil {
		t.Fatalf("get upload policy http error: %v", err)
	}
	if resp3.StatusCode != 200 {
		t.Fatalf("get upload policy status=%d body=%s", resp3.StatusCode, string(body3))
	}
	var policy uploadPolicyUserResponse
	if err := Decode(body3, &policy); err != nil {
		t.Fatalf("decode upload policy: %v body=%s", err, string(body3))
	}
	if policy.Version != newVersion {
		t.Fatalf("expected version=%q, got %q", newVersion, policy.Version)
	}
}

