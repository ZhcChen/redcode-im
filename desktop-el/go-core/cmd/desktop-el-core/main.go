package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"desktop-el-core/internal/rpc"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := run(ctx, os.Stdin, os.Stdout, os.Stderr); err != nil {
		fmt.Fprintf(os.Stderr, "[desktop-el-core] fatal: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, stdin io.Reader, stdout io.Writer, stderr io.Writer) error {
	encoder := rpc.NewEncoder(stdout)
	decoder := rpc.NewDecoder(stdin)
	server := rpc.NewServer()

	server.Register("core.ping", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return map[string]any{
			"ok":  true,
			"pid": os.Getpid(),
		}, nil
	})

	if err := encoder.EncodeEvent(rpc.Event{
		Type:  rpc.TypeEvent,
		Event: "core.ready",
		Data:  mustJSONRaw(map[string]any{"pid": os.Getpid()}),
	}); err != nil {
		return err
	}
	logf(stderr, "go core ready pid=%d", os.Getpid())

	if err := server.Serve(ctx, decoder, encoder); err != nil {
		if errors.Is(err, context.Canceled) {
			logf(stderr, "go core stopped")
			return nil
		}
		return err
	}

	logf(stderr, "go core stopped")
	return nil
}

func mustJSONRaw(v any) json.RawMessage {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return data
}

func logf(w io.Writer, format string, args ...any) {
	fmt.Fprintf(w, "[desktop-el-core] "+format+"\n", args...)
}
