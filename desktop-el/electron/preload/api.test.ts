import { beforeEach, describe, expect, test } from "bun:test";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const getExposedAPI = () => electronMockState.exposedAPI as
  | {
  rpc: {
    invoke: (method: string, params?: unknown, options?: { timeoutMs?: number; signal?: AbortSignal }) => Promise<unknown>;
  };
  file: {
    saveFromURL: (options: { url: string; filePath: string }) => Promise<unknown>;
    openPath: (path: string) => Promise<unknown>;
  };
}
  | undefined;

const { RPC_CANCEL_CHANNEL, RPC_INVOKE_CHANNEL } = await import("./types.js");
await import("./api.cts");

describe("desktopEl preload rpc api", () => {
  beforeEach(() => {
    resetElectronMockState();
  });

  test("serializes rpc request payload and forwards abort through cancel channel", async () => {
    const exposedAPI = getExposedAPI();
    expect(exposedAPI).toBeDefined();

    const controller = new AbortController();
    const invokePromise = exposedAPI!.rpc.invoke(
      "core.wait",
      { value: 1 },
      {
        timeoutMs: 250,
        signal: controller.signal
      }
    );

    expect(electronMockState.invokeArgs).toBeDefined();
    const [channel, payload] = electronMockState.invokeArgs!;
    expect(channel).toBe(RPC_INVOKE_CHANNEL);
    expect(payload).toMatchObject({
      type: "request",
      method: "core.wait",
      params: { value: 1 },
      timeout_ms: 250
    });
    expect((payload as { signal?: AbortSignal }).signal).toBeUndefined();
    expect(typeof (payload as { id: string }).id).toBe("string");

    controller.abort();

    expect(electronMockState.sentMessages).toEqual([
      [RPC_CANCEL_CHANNEL, { id: (payload as { id: string }).id }],
    ]);

    electronMockState.resolveInvoke?.({
      type: "response",
      id: (payload as { id: string }).id,
      result: { ok: true }
    });

    await expect(invokePromise).resolves.toEqual({ ok: true });
  });

  test("forwards file shell calls through shell invoke channel", async () => {
    const exposedAPI = getExposedAPI();
    expect(exposedAPI).toBeDefined();

    const savePromise = exposedAPI!.file.saveFromURL({
      url: "https://download.example.com/file.txt",
      filePath: "/tmp/file.txt"
    });

    expect(electronMockState.invokeArgs).toBeDefined();
    expect(electronMockState.invokeArgs).toEqual([
      "desktop-el:shell:invoke",
      {
        namespace: "file",
        method: "saveFromURL",
        params: {
          options: {
            url: "https://download.example.com/file.txt",
            filePath: "/tmp/file.txt"
          }
        }
      }
    ]);

    electronMockState.resolveInvoke?.({ filePath: "/tmp/file.txt" });
    await expect(savePromise).resolves.toEqual({ filePath: "/tmp/file.txt" });
  });
});
