package chat

import (
	"context"
	"net/http"
	"strconv"

	"desktop-el-core/internal/httpclient"
)

type EnsurePrivateChatParams struct {
	FriendUserID string `json:"friend_user_id"`
}

type ListMessagesParams struct {
	RoomID   string `json:"room_id"`
	Limit    int    `json:"limit,omitempty"`
	BeforeID string `json:"before_id,omitempty"`
	SinceID  string `json:"since_id,omitempty"`
}

type Service struct {
	client *httpclient.Client
}

func New(client *httpclient.Client) *Service {
	return &Service{client: client}
}

func (s *Service) ListChats(ctx context.Context) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/chats",
	})
}

func (s *Service) EnsurePrivateChat(ctx context.Context, params EnsurePrivateChatParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/friends/" + params.FriendUserID + "/chat",
		Body:   map[string]any{},
	})
}

func (s *Service) ListMessages(ctx context.Context, params ListMessagesParams) (httpclient.Response, error) {
	query := map[string]string{}
	if params.Limit > 0 {
		query["limit"] = strconv.Itoa(params.Limit)
	}
	if params.BeforeID != "" {
		query["before_id"] = params.BeforeID
	}
	if params.SinceID != "" {
		query["since_id"] = params.SinceID
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/messages",
		Query:  query,
	})
}
