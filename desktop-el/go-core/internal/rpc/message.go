package rpc

import "encoding/json"

type MessageType string

const (
	TypeRequest  MessageType = "request"
	TypeResponse MessageType = "response"
	TypeEvent    MessageType = "event"
)

type Request struct {
	Type      MessageType     `json:"type"`
	ID        string          `json:"id"`
	Method    string          `json:"method"`
	Params    json.RawMessage `json:"params,omitempty"`
	TimeoutMS *int            `json:"timeout_ms,omitempty"`
}

type Response struct {
	Type   MessageType     `json:"type"`
	ID     string          `json:"id"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *RPCError       `json:"error,omitempty"`
}

type Event struct {
	Type  MessageType     `json:"type"`
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data,omitempty"`
}
