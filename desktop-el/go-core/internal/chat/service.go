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

type SendMessageParams struct {
	RoomID  string `json:"room_id"`
	Content string `json:"content"`
}

type MarkReadUntilParams struct {
	RoomID    string `json:"room_id"`
	MessageID string `json:"message_id"`
}

type DeleteMessageParams struct {
	RoomID    string `json:"room_id"`
	MessageID string `json:"message_id"`
}

type AttachmentDownloadURLParams struct {
	RoomID           string `json:"room_id"`
	Key              string `json:"key"`
	ExpiresInSeconds int    `json:"expires_in_seconds,omitempty"`
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

func (s *Service) SendMessage(ctx context.Context, params SendMessageParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages",
		Body: map[string]any{
			"content": params.Content,
		},
	})
}

func (s *Service) MarkReadUntil(ctx context.Context, params MarkReadUntilParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages/read_until",
		Body: map[string]any{
			"message_id": params.MessageID,
		},
	})
}

func (s *Service) DeleteMessage(ctx context.Context, params DeleteMessageParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodDelete,
		Path:   "/rooms/" + params.RoomID + "/messages/" + params.MessageID,
	})
}

func (s *Service) GetAttachmentDownloadURL(ctx context.Context, params AttachmentDownloadURLParams) (httpclient.Response, error) {
	query := map[string]string{
		"key": params.Key,
	}
	if params.ExpiresInSeconds > 0 {
		query["expires_in_seconds"] = strconv.Itoa(params.ExpiresInSeconds)
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/messages/attachments/download",
		Query:  query,
	})
}
