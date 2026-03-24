package eventbus

import (
	"context"
	"testing"
)

func TestBusPublishAndUnsubscribe(t *testing.T) {
	bus := New()
	ctx := context.Background()

	var received Event
	unsubscribe := bus.Subscribe("core.bootstrap.snapshot", func(event Event) {
		received = event
	})

	bus.Publish(ctx, Event{
		Name: "core.bootstrap.snapshot",
		Data: map[string]any{"ready": true},
	})

	if received.Name != "core.bootstrap.snapshot" {
		t.Fatalf("unexpected event name: %+v", received)
	}

	unsubscribe()
	received = Event{}

	bus.Publish(ctx, Event{Name: "core.bootstrap.snapshot"})
	if received.Name != "" {
		t.Fatalf("expected handler to be unsubscribed, got: %+v", received)
	}
}
