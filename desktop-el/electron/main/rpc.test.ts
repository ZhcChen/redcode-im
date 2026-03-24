import { afterEach, beforeEach, describe, expect, mock, test } from "bun:test";

type IpcHandler = (_event: unknown, payload: unknown) => Promise<unknown>;
type IpcListener = (_event: unknown, payload: unknown) => void;

let registeredHandler: IpcHandler | undefined;
let cancelListener: IpcListener | undefined;
const sentEvents: Array<[string, unknown]> = [];

mock.module("electron", () => ({
  BrowserWindow: {
    getAllWindows: () => [
      {
        webContents: {
          send: (channel: string, payload: unknown) => {
            sentEvents.push([channel, payload]);
          }
        }
      }
    ]
  },
  ipcMain: {
    handle: (_channel: string, handler: IpcHandler) => {
      registeredHandler = handler;
    },
    on: (_channel: string, listener: IpcListener) => {
      cancelListener = listener;
    },
    off: (_channel: string, listener: IpcListener) => {
      if (cancelListener === listener) {
        cancelListener = undefined;
      }
    },
    removeHandler: (_channel: string) => {
      registeredHandler = undefined;
    }
  }
}));

const { RpcDispatcher, registerRpcIpc } = await import("./rpc.js");

describe("registerRpcIpc", () => {
  beforeEach(() => {
    registeredHandler = undefined;
    cancelListener = undefined;
    sentEvents.length = 0;
  });

  afterEach(() => {
    registeredHandler = undefined;
    cancelListener = undefined;
    sentEvents.length = 0;
  });

  test("preserves rpc error codes returned by dispatcher", async () => {
    const transport = {
      async send(request: { id: string }) {
        return {
          type: "response" as const,
          id: request.id,
          error: {
            code: "method_not_found" as const,
            message: "method not found"
          }
        };
      },
      onEvent() {
        return () => {};
      }
    };

    const cleanup = registerRpcIpc(new RpcDispatcher(transport));
    expect(registeredHandler).toBeDefined();

    const response = (await registeredHandler?.(undefined, {
      type: "request",
      id: "req-missing-1",
      method: "core.missing"
    })) as {
      error?: { code: string; message: string };
    };

    expect(response.error).toEqual({
      code: "method_not_found",
      message: "method not found"
    });

    cleanup();
  });

  test("aborts an in-flight request when cancel signal arrives", async () => {
    let transportSignal: AbortSignal | undefined;
    const transport = {
      send(request: { id: string }, signal?: AbortSignal) {
        transportSignal = signal;
        return new Promise((resolve) => {
          signal?.addEventListener(
            "abort",
            () => {
              resolve({
                type: "response" as const,
                id: request.id,
                error: {
                  code: "canceled" as const,
                  message: "request canceled"
                }
              });
            },
            { once: true }
          );
        });
      },
      onEvent() {
        return () => {};
      }
    };

    const cleanup = registerRpcIpc(new RpcDispatcher(transport));
    expect(registeredHandler).toBeDefined();
    expect(cancelListener).toBeDefined();

    const invokePromise = registeredHandler?.(undefined, {
      type: "request",
      id: "req-cancel-1",
      method: "core.wait"
    }) as Promise<{
      error?: { code: string; message: string };
    }>;

    expect(transportSignal).toBeDefined();
    expect(transportSignal?.aborted).toBeFalse();

    cancelListener?.(undefined, { id: "req-cancel-1" });

    const response = await invokePromise;
    expect(transportSignal?.aborted).toBeTrue();
    expect(response.error).toEqual({
      code: "canceled",
      message: "request canceled"
    });

    cleanup();
  });
});
