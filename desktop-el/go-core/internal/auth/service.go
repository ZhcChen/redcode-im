package auth

import (
	"context"
	"encoding/json"
	"net/http"

	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/session"
	"desktop-el-core/internal/state"
)

type BackendUser struct {
	ID        string  `json:"id"`
	Username  string  `json:"username"`
	Email     string  `json:"email"`
	Nickname  *string `json:"nickname,omitempty"`
	AvatarURL *string `json:"avatar_url,omitempty"`
	Status    string  `json:"status"`
}

type LoginResponse struct {
	Token        string      `json:"token"`
	RefreshToken string      `json:"refresh_token,omitempty"`
	User         BackendUser `json:"user"`
}

type LoginParams struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type SMSLoginParams struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

type SendSMSParams struct {
	Phone string `json:"phone"`
}

type SendSMSResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

type RegisterParams struct {
	Username string `json:"username"`
	Email    string `json:"email,omitempty"`
	Password string `json:"password"`
	Nickname string `json:"nickname,omitempty"`
}

type Service struct {
	client  *httpclient.Client
	session *session.Service
}

func New(client *httpclient.Client, sessionService *session.Service) *Service {
	return &Service{
		client:  client,
		session: sessionService,
	}
}

func (s *Service) Login(ctx context.Context, params LoginParams) (LoginResponse, error) {
	response, err := s.login(ctx, "/auth/login", params)
	if err != nil {
		return LoginResponse{}, err
	}

	var result LoginResponse
	if err := decodeData(response.Data, &result); err != nil {
		return LoginResponse{}, err
	}
	return result, nil
}

func (s *Service) LoginWithSMS(ctx context.Context, params SMSLoginParams) (LoginResponse, error) {
	response, err := s.login(ctx, "/auth/login/sms", params)
	if err != nil {
		return LoginResponse{}, err
	}

	var result LoginResponse
	if err := decodeData(response.Data, &result); err != nil {
		return LoginResponse{}, err
	}
	return result, nil
}

func (s *Service) SendLoginSMS(ctx context.Context, params SendSMSParams) (httpclient.Response, error) {
	response, err := s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/auth/sms/send",
		Body:   params,
		InjectToken: boolPtr(false),
	})
	if err != nil {
		return httpclient.Response{}, err
	}
	return response, nil
}

func (s *Service) GetCurrentUser(ctx context.Context) (httpclient.Response, error) {
	response, err := s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/auth/me",
	})
	if err != nil {
		return httpclient.Response{}, err
	}
	return response, nil
}

func (s *Service) LoginEnvelope(ctx context.Context, params LoginParams) (httpclient.Response, error) {
	return s.login(ctx, "/auth/login", params)
}

func (s *Service) LoginWithSMSEnvelope(ctx context.Context, params SMSLoginParams) (httpclient.Response, error) {
	return s.login(ctx, "/auth/login/sms", params)
}

func (s *Service) Register(ctx context.Context, params RegisterParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method:      http.MethodPost,
		Path:        "/auth/register",
		Body:        params,
		InjectToken: boolPtr(false),
	})
}

func (s *Service) login(ctx context.Context, path string, payload any) (httpclient.Response, error) {
	response, err := s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   path,
		Body:   payload,
		InjectToken: boolPtr(false),
	})
	if err != nil {
		return httpclient.Response{}, err
	}

	if !response.Success {
		return response, nil
	}

	var result LoginResponse
	if err := decodeData(response.Data, &result); err != nil {
		return httpclient.Response{}, err
	}
	s.session.Set(result.Token, result.RefreshToken)
	s.session.SetCurrentUser(mapBackendUserToSnapshot(result.User))
	s.client.SetToken(result.Token)
	return response, nil
}

func mapBackendUserToSnapshot(user BackendUser) state.UserSnapshot {
	return state.UserSnapshot{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Status:    user.Status,
	}
}

func decodeData(data json.RawMessage, target any) error {
	if len(data) == 0 || string(data) == "null" {
		return nil
	}
	return json.Unmarshal(data, target)
}

func boolPtr(value bool) *bool {
	return &value
}
