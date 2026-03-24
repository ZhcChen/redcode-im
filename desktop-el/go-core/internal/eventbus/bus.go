package eventbus

import (
	"context"
	"sync"
)

type Event struct {
	Name string
	Data any
}

type Handler func(Event)

type Bus struct {
	mu          sync.RWMutex
	nextID      uint64
	subscribers map[string]map[uint64]Handler
}

func New() *Bus {
	return &Bus{
		subscribers: make(map[string]map[uint64]Handler),
	}
}

func (b *Bus) Subscribe(name string, handler Handler) func() {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.nextID++
	id := b.nextID

	if b.subscribers[name] == nil {
		b.subscribers[name] = make(map[uint64]Handler)
	}
	b.subscribers[name][id] = handler

	return func() {
		b.mu.Lock()
		defer b.mu.Unlock()
		delete(b.subscribers[name], id)
		if len(b.subscribers[name]) == 0 {
			delete(b.subscribers, name)
		}
	}
}

func (b *Bus) Publish(ctx context.Context, event Event) {
	if ctx.Err() != nil {
		return
	}

	b.mu.RLock()
	handlers := make([]Handler, 0, len(b.subscribers[event.Name]))
	for _, handler := range b.subscribers[event.Name] {
		handlers = append(handlers, handler)
	}
	b.mu.RUnlock()

	for _, handler := range handlers {
		handler(event)
	}
}
