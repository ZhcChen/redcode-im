import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const { RpcDispatcher, registerRpcIpc } = await import("./rpc.js");

describe("registerRpcIpc", () => {
  beforeEach(() => {
    resetElectronMockState();
  });

  afterEach(() => {
    resetElectronMockState();
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
    expect(electronMockState.registeredHandler).toBeDefined();

    const response = (await electronMockState.registeredHandler?.(undefined, {
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
    expect(electronMockState.registeredHandler).toBeDefined();
    expect(electronMockState.cancelListener).toBeDefined();

    const invokePromise = electronMockState.registeredHandler?.(undefined, {
      type: "request",
      id: "req-cancel-1",
      method: "core.wait"
    }) as Promise<{
      error?: { code: string; message: string };
    }>;

    expect(transportSignal).toBeDefined();
    expect(transportSignal?.aborted).toBeFalse();

    electronMockState.cancelListener?.(undefined, { id: "req-cancel-1" });

    const response = await invokePromise;
    expect(transportSignal?.aborted).toBeTrue();
    expect(response.error).toEqual({
      code: "canceled",
      message: "request canceled"
    });

    cleanup();
  });
});
