package rpc

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"testing"
	"time"
)

func TestCodecEncodeDecodeRequestResponseEvent(t *testing.T) {
	var out bytes.Buffer
	encoder := NewEncoder(&out)

	req := Request{
		Type:   TypeRequest,
		ID:     "req-1",
		Method: "core.ping",
		Params: mustJSONRaw(t, map[string]any{"value": "ok"}),
	}
	if err := encoder.EncodeRequest(req); err != nil {
		t.Fatalf("encode request failed: %v", err)
	}

	res := Response{
		Type:   TypeResponse,
		ID:     "req-1",
		Result: mustJSONRaw(t, map[string]any{"pong": true}),
	}
	if err := encoder.EncodeResponse(res); err != nil {
		t.Fatalf("encode response failed: %v", err)
	}

	evt := Event{
		Type:  TypeEvent,
		Event: "core.status.updated",
		Data:  mustJSONRaw(t, map[string]any{"online": true}),
	}
	if err := encoder.EncodeEvent(evt); err != nil {
		t.Fatalf("encode event failed: %v", err)
	}

	decoder := NewDecoder(bytes.NewReader(out.Bytes()))

	gotReq, err := decoder.DecodeRequest()
	if err != nil {
		t.Fatalf("decode request failed: %v", err)
	}
	if gotReq.ID != req.ID || gotReq.Method != req.Method {
		t.Fatalf("request mismatch: %+v", gotReq)
	}

	gotRes, err := decoder.DecodeResponse()
	if err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	if gotRes.ID != res.ID {
		t.Fatalf("response id mismatch: %+v", gotRes)
	}

	gotEvt, err := decoder.DecodeEvent()
	if err != nil {
		t.Fatalf("decode event failed: %v", err)
	}
	if gotEvt.Event != evt.Event {
		t.Fatalf("event mismatch: %+v", gotEvt)
	}
}

func TestDecoderInvalidJSON(t *testing.T) {
	decoder := NewDecoder(strings.NewReader("{invalid-json}\n"))
	_, err := decoder.DecodeRequest()
	if !errors.Is(err, ErrInvalidJSON) {
		t.Fatalf("expected ErrInvalidJSON, got: %v", err)
	}
}

func TestDecoderMultiLineAndPartialRead(t *testing.T) {
	reader, writer := io.Pipe()
	defer writer.Close()

	decoder := NewDecoder(reader)

	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = writer.Write([]byte(`{"type":"request","id":"1","method":"core.echo","params":{"a":1}`))
		time.Sleep(20 * time.Millisecond)
		_, _ = writer.Write([]byte("}\n"))
		_, _ = writer.Write([]byte(`{"type":"event","event":"core.ready","data":{"ready":true}}` + "\n"))
	}()

	req, err := decoder.DecodeRequest()
	if err != nil {
		t.Fatalf("decode request from partial line failed: %v", err)
	}
	if req.ID != "1" {
		t.Fatalf("unexpected request id: %s", req.ID)
	}

	evt, err := decoder.DecodeEvent()
	if err != nil {
		t.Fatalf("decode event failed: %v", err)
	}
	if evt.Event != "core.ready" {
		t.Fatalf("unexpected event name: %s", evt.Event)
	}

	<-done
}

func TestServerUnknownMethod(t *testing.T) {
	server := NewServer()
	req := Request{
		Type:   TypeRequest,
		ID:     "unknown-1",
		Method: "core.noop",
	}

	res := server.HandleRequest(context.Background(), req)
	if res.Error == nil {
		t.Fatalf("expected error response")
	}
	if res.Error.Code != ErrCodeMethodNotFound {
		t.Fatalf("expected method not found code, got: %s", res.Error.Code)
	}
	if res.ID != req.ID {
		t.Fatalf("response id should match request id")
	}
}

func TestServerHandlerCancelAndTimeout(t *testing.T) {
	server := NewServer()

	server.Register("core.wait", func(ctx context.Context, _ json.RawMessage) (any, *RPCError) {
		select {
		case <-ctx.Done():
			return nil, ErrorFromContext(ctx.Err())
		case <-time.After(500 * time.Millisecond):
			return map[string]any{"ok": true}, nil
		}
	})

	t.Run("cancel", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		res := server.HandleRequest(ctx, Request{
			Type:   TypeRequest,
			ID:     "cancel-1",
			Method: "core.wait",
		})
		if res.Error == nil || res.Error.Code != ErrCodeCanceled {
			t.Fatalf("expected canceled error, got: %+v", res.Error)
		}
	})

	t.Run("timeout", func(t *testing.T) {
		timeoutMs := 10
		res := server.HandleRequest(context.Background(), Request{
			Type:      TypeRequest,
			ID:        "timeout-1",
			Method:    "core.wait",
			TimeoutMS: &timeoutMs,
		})
		if res.Error == nil || res.Error.Code != ErrCodeTimeout {
			t.Fatalf("expected timeout error, got: %+v", res.Error)
		}
	})
}

func TestServerServeEOFDoesNotEmitParseError(t *testing.T) {
	server := NewServer()
	decoder := NewDecoder(strings.NewReader(""))

	var out bytes.Buffer
	encoder := NewEncoder(&out)

	err := server.Serve(context.Background(), decoder, encoder)
	if err != nil {
		t.Fatalf("expected clean shutdown on EOF, got: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no protocol output on EOF, got: %q", out.String())
	}
}

func mustJSONRaw(t *testing.T, v any) json.RawMessage {
	t.Helper()

	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}
	return data
}
