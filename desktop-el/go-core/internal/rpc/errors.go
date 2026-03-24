package rpc

import (
	"context"
	"errors"
	"fmt"
)

const (
	ErrCodeParseError     = "parse_error"
	ErrCodeInvalidRequest = "invalid_request"
	ErrCodeMethodNotFound = "method_not_found"
	ErrCodeInvalidParams  = "invalid_params"
	ErrCodeInternal       = "internal"
	ErrCodeTimeout        = "timeout"
	ErrCodeCanceled       = "canceled"
)

var ErrInvalidJSON = errors.New("rpc: invalid json")

type RPCError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *RPCError) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func NewRPCError(code, message string) *RPCError {
	return &RPCError{
		Code:    code,
		Message: message,
	}
}

func ErrorFromContext(err error) *RPCError {
	if err == nil {
		return nil
	}

	switch {
	case errors.Is(err, context.Canceled):
		return NewRPCError(ErrCodeCanceled, "request canceled")
	case errors.Is(err, context.DeadlineExceeded):
		return NewRPCError(ErrCodeTimeout, "request timeout")
	default:
		return NewRPCError(ErrCodeInternal, err.Error())
	}
}
