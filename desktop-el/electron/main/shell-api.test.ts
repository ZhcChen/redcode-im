import { beforeEach, describe, expect, test } from "bun:test";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const { SHELL_INVOKE_CHANNEL } = await import("../preload/types.js");
const { registerShellIpc } = await import("./shell-api.js");

describe("registerShellIpc", () => {
  beforeEach(() => {
    resetElectronMockState();
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
      file: {
        saveFromURL: async () => ({ filePath: "/tmp/file.txt" }),
        openPath: async () => {}
      },
      notification: {
        isSupported: async () => true,
        show: async () => {}
      }
    });

    expect(electronMockState.registeredHandler).toBeDefined();

    const version = await electronMockState.registeredHandler?.(undefined, {
      namespace: "app",
      method: "getVersion"
    });

    expect(version).toBe("0.1.0");

    const saved = await electronMockState.registeredHandler?.(undefined, {
      namespace: "file",
      method: "saveFromURL",
      params: {
        options: {
          url: "https://download.example.com/file.txt",
          filePath: "/tmp/file.txt"
        }
      }
    });

    expect(saved).toEqual({ filePath: "/tmp/file.txt" });

    cleanup();
    expect(electronMockState.registeredHandler).toBeUndefined();
    expect(SHELL_INVOKE_CHANNEL).toBe("desktop-el:shell:invoke");
  });
});
