import { describe, expect, it } from 'vitest';

import { H5WebSocketService } from '@/services/websocket-service';

class MockSocket {
  readyState = 1;
  onopen: ((event: Event) => void) | null = null;
  onclose: ((event: CloseEvent) => void) | null = null;
  onerror: ((event: Event) => void) | null = null;
  onmessage: ((event: MessageEvent) => void) | null = null;
  sent: string[] = [];

  send(payload: string) {
    this.sent.push(payload);
  }

  close() {
    this.readyState = 3;
    this.onclose?.({} as CloseEvent);
  }

  emit(payload: Record<string, unknown>) {
    this.onmessage?.({ data: JSON.stringify(payload) } as MessageEvent);
  }
}

describe('H5WebSocketService', () => {
  it('authenticates with JSON protocol and joins desired rooms after authed', async () => {
    const sockets: MockSocket[] = [];
    let openedUrl = '';
    const service = new H5WebSocketService({
      autoReconnect: false,
      factory: (url) => {
        openedUrl = url;
        const socket = new MockSocket();
        sockets.push(socket);
        return socket;
      },
    });

    service.ensureRoomsSubscribed(['r1']);
    await service.connect('token-1');
    const socket = sockets[0];
    expect(socket).toBeDefined();
    socket?.onopen?.({} as Event);

    expect(openedUrl).toBe('ws://127.0.0.1:8010/ws?format=json');
    expect(socket?.sent.map((item) => JSON.parse(item))).toEqual([
      { type: 'auth', token: 'token-1' },
    ]);

    socket?.emit({ type: 'authed', user_id: 'u1', conn_id: 'c1' });
    expect(service.status).toBe('authenticated');
    expect(socket?.sent.map((item) => JSON.parse(item)).at(-1)).toEqual({
      type: 'join',
      room_id: 'r1',
    });
  });

  it('dispatches server events to listeners', async () => {
    const sockets: MockSocket[] = [];
    const service = new H5WebSocketService({
      autoReconnect: false,
      factory: () => {
        const socket = new MockSocket();
        sockets.push(socket);
        return socket;
      },
    });
    const events: string[] = [];
    service.onEvent((event) => events.push(event.type));

    await service.connect('token-1');
    const socket = sockets[0];
    expect(socket).toBeDefined();
    socket?.onopen?.({} as Event);
    socket?.emit({ type: 'message', room_id: 'r1', id: 'm1' });

    expect(events).toEqual(['message']);
  });
});
