package admin_test

import (
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

func TestAdminUserLocalizedErrors(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	t.Run("get user detail invalid user id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/users/not-a-uuid",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get user detail request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.user_id_invalid",
			"User ID is invalid.",
			nil,
		)
	})

	t.Run("get user detail user not found chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/users/550e8400-e29b-41d4-a716-446655440040",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("get user detail request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusNotFound,
			40401,
			"admin.user_not_found",
			"用户不存在",
			nil,
		)
	})

	t.Run("list feedbacks invalid user id english", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodGet,
			c.BaseURL+"/api/admin/feedbacks?userId=not-a-uuid",
			admin.Token,
			nil,
		)
		req.Header.Set("Accept-Language", "en-US")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("list feedbacks request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.user_id_invalid",
			"User ID is invalid.",
			nil,
		)
	})

	t.Run("check permission invalid user id chinese", func(t *testing.T) {
		req := testutil.NewAuthedJSONRequest(
			t,
			http.MethodPost,
			c.BaseURL+"/api/admin/permissions/check",
			admin.Token,
			map[string]any{
				"user_id":         "not-a-uuid",
				"permission_code": "user:view",
			},
		)
		req.Header.Set("Accept-Language", "zh-CN")

		resp, err := c.HTTP.Do(req)
		if err != nil {
			t.Fatalf("check permission request failed: %v", err)
		}
		defer resp.Body.Close()

		assertLocalizedAdminAdminUserError(
			t,
			resp,
			http.StatusBadRequest,
			42201,
			"admin.user_id_invalid",
			"无效的用户ID",
			nil,
		)
	})
}
