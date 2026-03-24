package ws

import (
	"context"
	"net/http"
	"net/url"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

type Status string

const (
	StatusDisconnected  Status = "disconnected"
	StatusConnecting    Status = "connecting"
	StatusAuthenticated Status = "authenticated"
)

type ConnectParams struct {
	URL   string
	Token string
}

type Client struct {
	mu     sync.RWMutex
	conn   *websocket.Conn
	status Status
}

func NewClient() *Client {
	return &Client{
		status: StatusDisconnected,
	}
}

func (c *Client) Connect(ctx context.Context, params ConnectParams) error {
	c.mu.Lock()
	c.status = StatusConnecting
	c.mu.Unlock()

	wsURL, err := withToken(params.URL, params.Token)
	if err != nil {
		c.setStatus(StatusDisconnected)
		return err
	}

	conn, resp, err := websocket.DefaultDialer.DialContext(ctx, wsURL, http.Header{})
	if resp != nil && resp.Body != nil {
		_ = resp.Body.Close()
	}
	if err != nil {
		c.setStatus(StatusDisconnected)
		return err
	}

	c.mu.Lock()
	if c.conn != nil {
		_ = c.conn.Close()
	}
	c.conn = conn
	c.status = StatusAuthenticated
	c.mu.Unlock()

	return nil
}

func (c *Client) Disconnect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		if err := c.conn.Close(); err != nil {
			return err
		}
		c.conn = nil
	}
	c.status = StatusDisconnected
	return nil
}

func (c *Client) Status() Status {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.status
}

func (c *Client) setStatus(status Status) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.status = status
}

func withToken(rawURL, token string) (string, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	values := parsed.Query()
	if token != "" {
		values.Set("token", token)
	}
	if strings.TrimSpace(values.Get("format")) == "" {
		values.Set("format", "json")
	}
	parsed.RawQuery = values.Encode()
	return parsed.String(), nil
}
