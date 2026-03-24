package user

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/session"
	"desktop-el-core/internal/state"
)

type BackendUser struct {
	ID              string  `json:"id"`
	Username        string  `json:"username"`
	Email           string  `json:"email"`
	Nickname        *string `json:"nickname,omitempty"`
	AvatarURL       *string `json:"avatar_url,omitempty"`
	AvatarObjectKey *string `json:"avatar_object_key,omitempty"`
	Status          string  `json:"status"`
}

type UpdateMeParams struct {
	Nickname  string `json:"nickname,omitempty"`
	AvatarURL string `json:"avatar_url,omitempty"`
}

type SearchUsersParams struct {
	Keyword string `json:"keyword"`
	Limit   int    `json:"limit,omitempty"`
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

func (s *Service) UpdateMe(ctx context.Context, params UpdateMeParams) (httpclient.Response, error) {
	response, err := s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPatch,
		Path:   "/users/me",
		Body:   params,
	})
	if err != nil {
		return httpclient.Response{}, err
	}

	if !response.Success {
		return response, nil
	}

	var result BackendUser
	if err := decodeData(response.Data, &result); err != nil {
		return httpclient.Response{}, err
	}
	s.session.SetCurrentUser(mapBackendUserToSnapshot(result))
	return response, nil
}

func (s *Service) SearchUsers(ctx context.Context, params SearchUsersParams) (httpclient.Response, error) {
	query := map[string]string{
		"keyword": params.Keyword,
	}
	if params.Limit > 0 {
		query["limit"] = stringInt(params.Limit)
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/users/search",
		Query:  query,
	})
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

func stringInt(value int) string {
	return strconv.Itoa(value)
}
