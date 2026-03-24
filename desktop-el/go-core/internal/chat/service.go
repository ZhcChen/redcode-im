package chat

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

func (s *Service) ListChats(ctx context.Context) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/chats",
	})
}
