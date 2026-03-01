package testutil

import (
	"net/http"
	"os"
	"strings"
	"time"
)

type Client struct {
	BaseURL string
	HTTP    *http.Client
}

func NewClient() *Client {
	base := os.Getenv("API_BASE_URL")
	if strings.TrimSpace(base) == "" {
		base = "http://localhost:8010"
	}
	return &Client{
		BaseURL: strings.TrimRight(base, "/"),
		HTTP: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}
