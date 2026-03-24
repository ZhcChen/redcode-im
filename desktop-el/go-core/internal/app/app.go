package app

import (
	"context"
	"encoding/json"

	"desktop-el-core/internal/bootstrap"
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/eventbus"
	"desktop-el-core/internal/rpc"
)

type App struct {
	config    config.Config
	bus       *eventbus.Bus
	bootstrap *bootstrap.Service
	encoder   *rpc.Encoder
}

func New(cfg config.Config, bus *eventbus.Bus, bootstrapService *bootstrap.Service, encoder *rpc.Encoder) *App {
	return &App{
		config:    cfg,
		bus:       bus,
		bootstrap: bootstrapService,
		encoder:   encoder,
	}
}

func (a *App) RegisterRPC() *rpc.Server {
	server := rpc.NewServer()

	server.Register("core.ping", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return map[string]any{
			"ok":          true,
			"app_name":    a.config.AppName,
			"environment": a.config.Environment,
		}, nil
	})

	server.Register("core.bootstrap.get", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return a.bootstrap.BuildSnapshot(), nil
	})

	return server
}

func (a *App) EmitBootstrapSnapshot(ctx context.Context) error {
	snapshot := a.bootstrap.BuildSnapshot()
	a.bus.Publish(ctx, eventbus.Event{
		Name: "core.bootstrap.snapshot",
		Data: snapshot,
	})

	return a.encoder.EncodeEvent(rpc.Event{
		Type:  rpc.TypeEvent,
		Event: "core.bootstrap.snapshot",
		Data:  mustJSONRaw(snapshot),
	})
}

func mustJSONRaw(v any) json.RawMessage {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return data
}
