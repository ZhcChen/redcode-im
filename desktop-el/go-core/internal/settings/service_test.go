package settings

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/httpclient"
)

func TestServiceRequestsPublicSettingsWithoutAuthHeader(t *testing.T) {
	testCases := []struct {
		name string
		path string
		call func(service *Service) (httpclient.Response, error)
	}{
		{
			name: "captcha",
			path: "/settings/captcha",
			call: func(service *Service) (httpclient.Response, error) {
				return service.GetCaptchaSetting(context.Background())
			},
		},
		{
			name: "privacy policy",
			path: "/settings/privacy-policy",
			call: func(service *Service) (httpclient.Response, error) {
				return service.GetPrivacyPolicy(context.Background())
			},
		},
		{
			name: "user agreement",
			path: "/settings/user-agreement",
			call: func(service *Service) (httpclient.Response, error) {
				return service.GetUserAgreement(context.Background())
			},
		},
		{
			name: "app name",
			path: "/settings/app-name",
			call: func(service *Service) (httpclient.Response, error) {
				return service.GetAppName(context.Background())
			},
		},
		{
			name: "general settings",
			path: "/settings/general",
			call: func(service *Service) (httpclient.Response, error) {
				return service.GetGeneralSettings(context.Background())
			},
		},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != testCase.path {
					t.Fatalf("unexpected path: %s", r.URL.Path)
				}
				if r.Method != http.MethodGet {
					t.Fatalf("unexpected method: %s", r.Method)
				}
				if got := r.Header.Get("Authorization"); got != "" {
					t.Fatalf("expected public settings request without auth header, got: %s", got)
				}

				_ = json.NewEncoder(w).Encode(map[string]any{
					"success": true,
					"code":    200,
					"message": "ok",
					"data":    map[string]any{},
				})
			}))
			defer server.Close()

			client := httpclient.New(httpclient.Config{BaseURL: server.URL})
			client.SetToken("access-token")
			service := New(client)

			if _, err := testCase.call(service); err != nil {
				t.Fatalf("settings request failed: %v", err)
			}
		})
	}
}
