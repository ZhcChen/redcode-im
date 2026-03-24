import { beforeEach, describe, expect, mock, test } from "bun:test";

let invokeArgs: [string, unknown] | undefined;
const sentMessages: Array<[string, unknown]> = [];
let exposedAPI: {
  rpc: {
    invoke: (method: string, params?: unknown, options?: { timeoutMs?: number; signal?: AbortSignal }) => Promise<unknown>;
  };
  file: {
    saveFromURL: (options: { url: string; filePath: string }) => Promise<unknown>;
    openPath: (path: string) => Promise<unknown>;
  };
} | undefined;
let resolveInvoke: ((value: unknown) => void) | undefined;

mock.module("electron", () => ({
  contextBridge: {
    exposeInMainWorld: (_key: string, api: unknown) => {
      exposedAPI = api as typeof exposedAPI;
    }
  },
  ipcRenderer: {
    invoke: (channel: string, payload: unknown) => {
      invokeArgs = [channel, payload];
      return new Promise((resolve) => {
        resolveInvoke = resolve;
      });
    },
    send: (channel: string, payload: unknown) => {
      sentMessages.push([channel, payload]);
    },
    on: () => {},
    off: () => {}
  }
}));

const { RPC_CANCEL_CHANNEL, RPC_INVOKE_CHANNEL } = await import("./types.js");
await import("./api.cts");

describe("desktopEl preload rpc api", () => {
  beforeEach(() => {
    invokeArgs = undefined;
    sentMessages.length = 0;
    resolveInvoke = undefined;
  });

  test("serializes rpc request payload and forwards abort through cancel channel", async () => {
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

    expect(invokeArgs).toBeDefined();
    const [channel, payload] = invokeArgs!;
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

    expect(sentMessages).toEqual([[RPC_CANCEL_CHANNEL, { id: (payload as { id: string }).id }]]);

    resolveInvoke?.({
      type: "response",
      id: (payload as { id: string }).id,
      result: { ok: true }
    });

    await expect(invokePromise).resolves.toEqual({ ok: true });
  });

  test("forwards file shell calls through shell invoke channel", async () => {
    expect(exposedAPI).toBeDefined();

    const savePromise = exposedAPI!.file.saveFromURL({
      url: "https://download.example.com/file.txt",
      filePath: "/tmp/file.txt"
    });

    expect(invokeArgs).toBeDefined();
    expect(invokeArgs).toEqual([
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

    resolveInvoke?.({ filePath: "/tmp/file.txt" });
    await expect(savePromise).resolves.toEqual({ filePath: "/tmp/file.txt" });
  });
});
