package httpclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

type Config struct {
	BaseURL string
	Timeout time.Duration
	Client  *http.Client
}

type Request struct {
	Method      string
	Path        string
	Headers     map[string]string
	Query       map[string]string
	Body        any
	InjectToken *bool
}

type Response struct {
	Success bool            `json:"success"`
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

type Client struct {
	baseURL string
	client  *http.Client

	mu    sync.RWMutex
	token string
}

func New(cfg Config) *Client {
	httpClient := cfg.Client
	if httpClient == nil {
		timeout := cfg.Timeout
		if timeout <= 0 {
			timeout = 15 * time.Second
		}
		httpClient = &http.Client{Timeout: timeout}
	}

	return &Client{
		baseURL: strings.TrimRight(cfg.BaseURL, "/"),
		client:  httpClient,
	}
}

func (c *Client) SetToken(token string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.token = token
}

func (c *Client) ClearToken() {
	c.SetToken("")
}

func (c *Client) Do(ctx context.Context, req Request) (Response, error) {
	requestURL, err := c.buildURL(req.Path, req.Query)
	if err != nil {
		return Response{}, err
	}

	bodyReader, err := c.buildBody(req.Body)
	if err != nil {
		return Response{}, err
	}

	method := req.Method
	if method == "" {
		method = http.MethodGet
	}

	httpReq, err := http.NewRequestWithContext(ctx, method, requestURL, bodyReader)
	if err != nil {
		return Response{}, err
	}

	for key, value := range req.Headers {
		httpReq.Header.Set(key, value)
	}
	if req.Body != nil && httpReq.Header.Get("Content-Type") == "" {
		httpReq.Header.Set("Content-Type", "application/json")
	}
	shouldInjectToken := true
	if req.InjectToken != nil {
		shouldInjectToken = *req.InjectToken
	}
	if shouldInjectToken {
		if token := c.AccessToken(); token != "" {
			httpReq.Header.Set("Authorization", "Bearer "+token)
		}
	}

	httpResp, err := c.client.Do(httpReq)
	if err != nil {
		return Response{}, err
	}
	defer httpResp.Body.Close()

	payload, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return Response{}, err
	}

	return decodeResponse(httpResp.StatusCode, payload)
}

func (c *Client) AccessToken() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.token
}

func (c *Client) buildURL(path string, query map[string]string) (string, error) {
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return appendQuery(path, query)
	}
	if c.baseURL == "" {
		return "", fmt.Errorf("http client base url is empty")
	}
	return appendQuery(c.baseURL+path, query)
}

func appendQuery(rawURL string, query map[string]string) (string, error) {
	if len(query) == 0 {
		return rawURL, nil
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	values := parsed.Query()
	for key, value := range query {
		values.Set(key, value)
	}
	parsed.RawQuery = values.Encode()
	return parsed.String(), nil
}

func (c *Client) buildBody(body any) (io.Reader, error) {
	if body == nil {
		return nil, nil
	}
	if reader, ok := body.(io.Reader); ok {
		return reader, nil
	}

	data, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	return bytes.NewReader(data), nil
}

func decodeResponse(statusCode int, payload []byte) (Response, error) {
	trimmed := bytes.TrimSpace(payload)
	if len(trimmed) == 0 {
		return Response{
			Success: isHTTPSuccess(statusCode),
			Code:    statusCode,
			Message: defaultMessage(statusCode),
			Data:    json.RawMessage("null"),
		}, nil
	}

	var object map[string]json.RawMessage
	if err := json.Unmarshal(trimmed, &object); err == nil {
		if isEnvelopeObject(object) {
			var response Response
			if err := json.Unmarshal(trimmed, &response); err != nil {
				return Response{}, fmt.Errorf("decode http response envelope: %w", err)
			}
			if response.Code == 0 {
				response.Code = statusCode
			}
			if response.Message == "" {
				response.Message = defaultMessage(statusCode)
			}
			if len(response.Data) == 0 {
				if _, hasData := object["data"]; hasData {
					response.Data = json.RawMessage("null")
				} else {
					response.Data = json.RawMessage(trimmed)
				}
			}
			return response, nil
		}

		if isErrorObject(object) {
			response := Response{
				Success: false,
				Code:    statusCode,
				Message: defaultMessage(statusCode),
				Data:    json.RawMessage("null"),
			}
			if rawCode, ok := object["code"]; ok {
				_ = json.Unmarshal(rawCode, &response.Code)
			}
			if rawMessage, ok := object["message"]; ok {
				_ = json.Unmarshal(rawMessage, &response.Message)
			}
			return response, nil
		}
	}

	if !json.Valid(trimmed) {
		return Response{
			Success: isHTTPSuccess(statusCode),
			Code:    statusCode,
			Message: string(trimmed),
			Data:    json.RawMessage("null"),
		}, nil
	}

	return Response{
		Success: isHTTPSuccess(statusCode),
		Code:    statusCode,
		Message: defaultMessage(statusCode),
		Data:    json.RawMessage(trimmed),
	}, nil
}

func isEnvelopeObject(object map[string]json.RawMessage) bool {
	if _, ok := object["success"]; ok {
		return true
	}
	_, hasData := object["data"]
	_, hasMessage := object["message"]
	_, hasCode := object["code"]
	return hasData && (hasMessage || hasCode)
}

func isErrorObject(object map[string]json.RawMessage) bool {
	if _, ok := object["success"]; ok {
		return false
	}
	_, hasCode := object["code"]
	_, hasMessage := object["message"]
	return hasCode && hasMessage
}

func isHTTPSuccess(statusCode int) bool {
	return statusCode >= http.StatusOK && statusCode < http.StatusMultipleChoices
}

func defaultMessage(statusCode int) string {
	message := http.StatusText(statusCode)
	if message != "" {
		return message
	}
	if isHTTPSuccess(statusCode) {
		return "ok"
	}
	return "request failed"
}
