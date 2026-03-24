package settings

import (
	"context"
	"net/http"

	"desktop-el-core/internal/httpclient"
)

type Service struct {
	client *httpclient.Client
}

func New(client *httpclient.Client) *Service {
	return &Service{client: client}
}

func (s *Service) GetCaptchaSetting(ctx context.Context) (httpclient.Response, error) {
	return s.request(ctx, "/settings/captcha")
}

func (s *Service) GetPrivacyPolicy(ctx context.Context) (httpclient.Response, error) {
	return s.request(ctx, "/settings/privacy-policy")
}

func (s *Service) GetUserAgreement(ctx context.Context) (httpclient.Response, error) {
	return s.request(ctx, "/settings/user-agreement")
}

func (s *Service) GetAppName(ctx context.Context) (httpclient.Response, error) {
	return s.request(ctx, "/settings/app-name")
}

func (s *Service) GetGeneralSettings(ctx context.Context) (httpclient.Response, error) {
	return s.request(ctx, "/settings/general")
}

func (s *Service) request(ctx context.Context, path string) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method:      http.MethodGet,
		Path:        path,
		InjectToken: boolPtr(false),
	})
}

func boolPtr(value bool) *bool {
	return &value
}
