package backend_message_search

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type Client struct {
	BaseURL string
	HTTP    *http.Client
}

func NewClient() *Client {
	base := os.Getenv("API_BASE_URL")
	if base == "" {
		base = "http://localhost:8010"
	}
	return &Client{
		BaseURL: base,
		HTTP: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

type ApiResponse[T any] struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    T      `json:"data"`
}

func Decode[T any](data []byte, target *T) error {
	return json.Unmarshal(data, target)
}

func (c *Client) DoJSON(method, path string, body any, token string) (*http.Response, []byte, error) {
	url := c.BaseURL + path
	var reader io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			return nil, nil, err
		}
		reader = bytes.NewReader(buf)
	}

	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp, nil, err
	}
	return resp, bodyBytes, nil
}

func UnmarshalAPI[T any](data []byte) (ApiResponse[T], error) {
	var resp ApiResponse[T]
	if err := json.Unmarshal(data, &resp); err != nil {
		return resp, fmt.Errorf("decode api response: %w", err)
	}
	return resp, nil
}

