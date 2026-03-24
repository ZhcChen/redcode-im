package rpc

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"sync"
	"time"
)

type Handler func(ctx context.Context, params json.RawMessage) (any, *RPCError)

type Server struct {
	mu       sync.RWMutex
	handlers map[string]Handler
}

func NewServer() *Server {
	return &Server{
		handlers: make(map[string]Handler),
	}
}

func (s *Server) Register(method string, handler Handler) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.handlers[method] = handler
}

func (s *Server) HandleRequest(ctx context.Context, req Request) Response {
	res := Response{
		Type: TypeResponse,
		ID:   req.ID,
	}

	if req.Type != TypeRequest {
		res.Error = NewRPCError(ErrCodeInvalidRequest, "message type must be request")
		return res
	}
	if req.Method == "" {
		res.Error = NewRPCError(ErrCodeInvalidRequest, "method is required")
		return res
	}

	handler := s.lookup(req.Method)
	if handler == nil {
		res.Error = NewRPCError(ErrCodeMethodNotFound, "method not found")
		return res
	}

	reqCtx := ctx
	cancel := func() {}
	if req.TimeoutMS != nil && *req.TimeoutMS > 0 {
		reqCtx, cancel = context.WithTimeout(ctx, time.Duration(*req.TimeoutMS)*time.Millisecond)
	}
	defer cancel()

	result, handlerErr := handler(reqCtx, req.Params)
	if handlerErr != nil {
		res.Error = handlerErr
		return res
	}

	if reqCtx.Err() != nil {
		res.Error = ErrorFromContext(reqCtx.Err())
		return res
	}

	rawResult, err := marshalResult(result)
	if err != nil {
		res.Error = NewRPCError(ErrCodeInternal, err.Error())
		return res
	}
	res.Result = rawResult
	return res
}

func (s *Server) lookup(method string) Handler {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.handlers[method]
}

func marshalResult(v any) (json.RawMessage, error) {
	if v == nil {
		return nil, nil
	}
	if raw, ok := v.(json.RawMessage); ok {
		return raw, nil
	}
	data, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	return data, nil
}

func (s *Server) Serve(ctx context.Context, decoder *Decoder, encoder *Encoder) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		req, err := decoder.DecodeRequest()
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
				return err
			}
			if errors.Is(err, io.EOF) {
				return nil
			}
			res := Response{
				Type: TypeResponse,
				Error: NewRPCError(
					ErrCodeParseError,
					err.Error(),
				),
			}
			if encodeErr := encoder.EncodeResponse(res); encodeErr != nil {
				return encodeErr
			}
			if errors.Is(err, ErrInvalidJSON) {
				continue
			}
			return err
		}

		res := s.HandleRequest(ctx, req)
		if err := encoder.EncodeResponse(res); err != nil {
			return err
		}
	}
}
