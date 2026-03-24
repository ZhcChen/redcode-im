package ws

import (
	"context"

	"desktop-el-core/internal/eventbus"
)

type Dispatcher struct {
	bus *eventbus.Bus
}

func NewDispatcher(bus *eventbus.Bus) *Dispatcher {
	return &Dispatcher{bus: bus}
}

func (d *Dispatcher) PublishStatus(ctx context.Context, status Status) {
	if d == nil || d.bus == nil {
		return
	}
	d.bus.Publish(ctx, eventbus.Event{
		Name: "ws.status.updated",
		Data: map[string]any{
			"status": string(status),
		},
	})
}
