import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { WebSocketApi } from "./websocket";

describe("websocket api", () => {
  const originalWindow = globalThis.window;
  let calls: Array<{
    method: string;
    params: Record<string, unknown> | undefined;
  }> = [];

  beforeEach(() => {
    calls = [];
  });

  afterEach(() => {
    if (originalWindow) {
      globalThis.window = originalWindow;
      return;
    }
    Reflect.deleteProperty(globalThis, "window");
  });

  test("joins room through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return { success: true };
          },
        },
      },
    } as Window;

    await WebSocketApi.joinRoom("room-2");

    expect(calls).toEqual([
      {
        method: "ws.join",
        params: {
          room_id: "room-2",
        },
      },
    ]);
  });

  test("leaves room through go-core rpc", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return { success: true };
          },
        },
      },
    } as Window;

    await WebSocketApi.leaveRoom("room-2");

    expect(calls).toEqual([
      {
        method: "ws.leave",
        params: {
          room_id: "room-2",
        },
      },
    ]);
  });
});
