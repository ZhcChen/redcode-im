package main

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"

	"desktop-el-core/internal/rpc"
)

func TestRunEmitsReadyEventAndRespondsToPing(t *testing.T) {
	input := strings.NewReader("{\"type\":\"request\",\"id\":\"req-1\",\"method\":\"core.ping\"}\n")

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	if err := run(context.Background(), input, &stdout, &stderr); err != nil {
		t.Fatalf("run failed: %v", err)
	}

	lines := bytes.Split(bytes.TrimSpace(stdout.Bytes()), []byte("\n"))
	if len(lines) != 3 {
		t.Fatalf("expected 3 protocol lines, got %d: %q", len(lines), stdout.String())
	}

	var ready rpc.Event
	if err := json.Unmarshal(lines[0], &ready); err != nil {
		t.Fatalf("decode ready event failed: %v", err)
	}
	if ready.Type != rpc.TypeEvent || ready.Event != "core.ready" {
		t.Fatalf("unexpected ready event: %+v", ready)
	}

	var bootstrap rpc.Event
	if err := json.Unmarshal(lines[1], &bootstrap); err != nil {
		t.Fatalf("decode bootstrap event failed: %v", err)
	}
	if bootstrap.Type != rpc.TypeEvent || bootstrap.Event != "core.bootstrap.snapshot" {
		t.Fatalf("unexpected bootstrap event: %+v", bootstrap)
	}

	var response rpc.Response
	if err := json.Unmarshal(lines[2], &response); err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	if response.Type != rpc.TypeResponse || response.ID != "req-1" {
		t.Fatalf("unexpected response envelope: %+v", response)
	}
	if response.Error != nil {
		t.Fatalf("expected success response, got error: %+v", response.Error)
	}

	var result map[string]any
	if err := json.Unmarshal(response.Result, &result); err != nil {
		t.Fatalf("decode result failed: %v", err)
	}
	if result["ok"] != true {
		t.Fatalf("expected ping result ok=true, got: %+v", result)
	}
	if result["app_name"] != "RedCode IM" {
		t.Fatalf("expected app_name in ping result, got: %+v", result)
	}

	if strings.Contains(stdout.String(), "scaffold is running") {
		t.Fatalf("expected stdout to contain only protocol messages, got: %q", stdout.String())
	}
}
