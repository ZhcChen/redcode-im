package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type userAccountLimitResponse struct {
	EnablePhoneValidation        bool `json:"enable_phone_validation"`
	EnableEmailValidation        bool `json:"enable_email_validation"`
	EnableLengthValidation       bool `json:"enable_length_validation"`
	MinLength                    int  `json:"min_length"`
	MaxLength                    int  `json:"max_length"`
	EnableAlphanumericValidation bool `json:"enable_alphanumeric_validation"`
}

func TestAdmin_UserAccountLimit_GetAndUpdate_Idempotent(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip user account limit test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	resp0, body0, err := c.DoJSON("GET", "/api/admin/settings/user-account-limit", nil, admin.Token)
	if err != nil {
		t.Fatalf("get user account limit http error: %v", err)
	}
	if resp0.StatusCode != 200 {
		t.Fatalf("get user account limit status=%d body=%s", resp0.StatusCode, string(body0))
	}
	var original userAccountLimitResponse
	if err := testutil.DecodeJSON(body0, &original); err != nil {
		t.Fatalf("decode user account limit: %v body=%s", err, string(body0))
	}

	// 用“原样回写”的方式覆盖 update 接口，但不改变行为，避免影响并行用例（注册/登录）
	resp1, body1, err := c.DoJSON("PUT", "/api/admin/settings/user-account-limit", map[string]any{
		"enable_phone_validation":        original.EnablePhoneValidation,
		"enable_email_validation":        original.EnableEmailValidation,
		"enable_length_validation":       original.EnableLengthValidation,
		"min_length":                     original.MinLength,
		"max_length":                     original.MaxLength,
		"enable_alphanumeric_validation": original.EnableAlphanumericValidation,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user account limit http error: %v", err)
	}
	if resp1.StatusCode != 200 {
		t.Fatalf("update user account limit status=%d body=%s", resp1.StatusCode, string(body1))
	}
	var updated userAccountLimitResponse
	if err := testutil.DecodeJSON(body1, &updated); err != nil {
		t.Fatalf("decode updated user account limit: %v body=%s", err, string(body1))
	}
	if updated != original {
		t.Fatalf("expected updated == original, original=%+v updated=%+v", original, updated)
	}
}

func TestAdmin_UserAccountLimit_Update_Validations(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip user account limit validation test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	// all false => 400
	resp0, body0, err := c.DoJSON("PUT", "/api/admin/settings/user-account-limit", map[string]any{
		"enable_phone_validation":        false,
		"enable_email_validation":        false,
		"enable_length_validation":       false,
		"min_length":                     3,
		"max_length":                     20,
		"enable_alphanumeric_validation": false,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user account limit (all false) http error: %v", err)
	}
	if resp0.StatusCode != 400 {
		t.Fatalf("expected update user account limit (all false)=400, got %d body=%s", resp0.StatusCode, string(body0))
	}

	// enable_length_validation but invalid range => 400
	resp1, body1, err := c.DoJSON("PUT", "/api/admin/settings/user-account-limit", map[string]any{
		"enable_phone_validation":        true,
		"enable_email_validation":        false,
		"enable_length_validation":       true,
		"min_length":                     2,
		"max_length":                     51,
		"enable_alphanumeric_validation": false,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user account limit (bad length range) http error: %v", err)
	}
	if resp1.StatusCode != 400 {
		t.Fatalf("expected update user account limit (bad length range)=400, got %d body=%s", resp1.StatusCode, string(body1))
	}

	resp2, body2, err := c.DoJSON("PUT", "/api/admin/settings/user-account-limit", map[string]any{
		"enable_phone_validation":        true,
		"enable_email_validation":        false,
		"enable_length_validation":       true,
		"min_length":                     10,
		"max_length":                     3,
		"enable_alphanumeric_validation": false,
	}, admin.Token)
	if err != nil {
		t.Fatalf("update user account limit (min>max) http error: %v", err)
	}
	if resp2.StatusCode != 400 {
		t.Fatalf("expected update user account limit (min>max)=400, got %d body=%s", resp2.StatusCode, string(body2))
	}
}

