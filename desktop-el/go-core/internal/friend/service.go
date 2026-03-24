package friend

import (
	"context"
	"net/http"

	"desktop-el-core/internal/httpclient"
)

type ListFriendRequestsParams struct {
	Direction string `json:"direction,omitempty"`
	Status    string `json:"status,omitempty"`
}

type RespondFriendRequestParams struct {
	RequestID string `json:"request_id"`
	Action    string `json:"action"`
}

type Service struct {
	client *httpclient.Client
}

func New(client *httpclient.Client) *Service {
	return &Service{client: client}
}

func (s *Service) ListFriends(ctx context.Context) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/friends",
	})
}

func (s *Service) ListFriendRequests(ctx context.Context, params ListFriendRequestsParams) (httpclient.Response, error) {
	query := map[string]string{}
	if params.Direction != "" {
		query["direction"] = params.Direction
	}
	if params.Status != "" {
		query["status"] = params.Status
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/friends/requests",
		Query:  query,
	})
}

func (s *Service) RespondFriendRequest(ctx context.Context, params RespondFriendRequestParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/friends/requests/" + params.RequestID + "/respond",
		Body: map[string]string{
			"action": params.Action,
		},
	})
}
