package ws

import (
	"context"
	"errors"
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

var ErrNotConnected = errors.New("websocket not connected")

type ConnectParams struct {
	URL   string
	Token string
}

type Client struct {
	mu      sync.RWMutex
	writeMu sync.Mutex
	conn    *websocket.Conn
	status  Status
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
	conn := c.conn
	c.conn = nil
	c.status = StatusDisconnected
	c.mu.Unlock()

	if conn != nil {
		if err := conn.Close(); err != nil {
			return err
		}
	}
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

func (c *Client) ReadMessage(_ context.Context) ([]byte, error) {
	c.mu.RLock()
	conn := c.conn
	c.mu.RUnlock()

	if conn == nil {
		return nil, ErrNotConnected
	}

	_, payload, err := conn.ReadMessage()
	if err != nil {
		c.mu.Lock()
		if c.conn == conn {
			c.conn = nil
			c.status = StatusDisconnected
		}
		c.mu.Unlock()
		return nil, err
	}

	return payload, nil
}

func (c *Client) WriteJSON(_ context.Context, payload any) error {
	c.mu.RLock()
	conn := c.conn
	c.mu.RUnlock()

	if conn == nil {
		return ErrNotConnected
	}

	c.writeMu.Lock()
	defer c.writeMu.Unlock()

	if err := conn.WriteJSON(payload); err != nil {
		c.mu.Lock()
		if c.conn == conn {
			c.conn = nil
			c.status = StatusDisconnected
		}
		c.mu.Unlock()
		return err
	}

	return nil
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
