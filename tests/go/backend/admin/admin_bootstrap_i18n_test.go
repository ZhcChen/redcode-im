package admin_test

import (
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestAdminBootstrapLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()

	t.Run("init default admin already exists english", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodPost, c.BaseURL+"/api/admin/init-default-admin", nil)
		if err != nil {
			t.Fatalf("new request failed: %v", err)
		}
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("init default admin request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			false,
			"Default admin user already exists. No action taken.",
		)
	})

	t.Run("reset admin password success english", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodPost, c.BaseURL+"/api/admin/reset-admin-password", nil)
		if err != nil {
			t.Fatalf("new request failed: %v", err)
		}
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("reset admin password request failed: %v", err)
		}
		defer resp.Body.Close()

		assertAdminOperationResponse(
			t,
			resp,
			http.StatusOK,
			true,
			"Admin password reset successfully. Password: admin123",
		)
	})
}
