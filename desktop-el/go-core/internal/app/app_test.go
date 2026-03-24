package app

import (
	"bytes"
	"context"
	"encoding/json"
	"testing"

	"desktop-el-core/internal/bootstrap"
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/eventbus"
	"desktop-el-core/internal/rpc"
)

func TestAppRegistersBootstrapRPCAndEmitsSnapshotEvent(t *testing.T) {
	var stdout bytes.Buffer

	application := New(
		config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			FeatureFlags: map[string]bool{
				"desktop_el": true,
			},
		},
		eventbus.New(),
		bootstrap.New(config.Config{
			AppName:     "RedCode IM",
			Environment: "development",
			FeatureFlags: map[string]bool{
				"desktop_el": true,
			},
		}),
		rpc.NewEncoder(&stdout),
	)

	server := application.RegisterRPC()

	response := server.HandleRequest(context.Background(), rpc.Request{
		Type:   rpc.TypeRequest,
		ID:     "req-bootstrap-1",
		Method: "core.bootstrap.get",
	})
	if response.Error != nil {
		t.Fatalf("expected bootstrap request to succeed, got: %+v", response.Error)
	}

	var snapshot map[string]any
	if err := json.Unmarshal(response.Result, &snapshot); err != nil {
		t.Fatalf("decode bootstrap result failed: %v", err)
	}
	if snapshot["feature_flags"] == nil {
		t.Fatalf("expected feature_flags in bootstrap snapshot: %+v", snapshot)
	}

	if err := application.EmitBootstrapSnapshot(context.Background()); err != nil {
		t.Fatalf("emit bootstrap snapshot failed: %v", err)
	}

	var event rpc.Event
	if err := json.Unmarshal(bytes.TrimSpace(stdout.Bytes()), &event); err != nil {
		t.Fatalf("decode emitted event failed: %v", err)
	}
	if event.Event != "core.bootstrap.snapshot" {
		t.Fatalf("unexpected emitted event: %+v", event)
	}
}
