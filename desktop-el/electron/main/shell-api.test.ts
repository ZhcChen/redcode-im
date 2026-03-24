import { beforeEach, describe, expect, mock, test } from "bun:test";

type IpcHandler = (_event: unknown, payload: unknown) => Promise<unknown>;

let registeredHandler: IpcHandler | undefined;

mock.module("electron", () => ({
  ipcMain: {
    handle: (_channel: string, handler: IpcHandler) => {
      registeredHandler = handler;
    },
    removeHandler: () => {
      registeredHandler = undefined;
    }
  }
}));

const { SHELL_INVOKE_CHANNEL } = await import("../preload/types.js");
const { registerShellIpc } = await import("./shell-api.js");

describe("registerShellIpc", () => {
  beforeEach(() => {
    registeredHandler = undefined;
  });

  test("dispatches shell calls to the requested namespace", async () => {
    const cleanup = registerShellIpc({
      app: {
        getVersion: async () => "0.1.0",
        quit: async () => {}
      },
      window: {
        show: async () => {},
        hide: async () => {},
        focus: async () => {},
        setTitle: async () => {}
      },
      dialog: {
        open: async () => ({ canceled: false, filePaths: ["/tmp/file.txt"] }),
        save: async () => ({ canceled: false, filePath: "/tmp/file.txt" })
      },
      notification: {
        isSupported: async () => true,
        show: async () => {}
      }
    });

    expect(registeredHandler).toBeDefined();

    const version = await registeredHandler?.(undefined, {
      namespace: "app",
      method: "getVersion"
    });

    expect(version).toBe("0.1.0");

    cleanup();
    expect(registeredHandler).toBeUndefined();
    expect(SHELL_INVOKE_CHANNEL).toBe("desktop-el:shell:invoke");
  });
});
