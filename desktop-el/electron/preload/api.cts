import { contextBridge, ipcRenderer } from "electron";
import type {
  DesktopDialogOpenOptions,
  DesktopDialogOpenResult,
  DesktopDialogSaveOptions,
  DesktopDialogSaveResult,
  DesktopElAPI,
  DesktopNotificationPayload,
  RpcError,
  RpcEvent,
  RpcInvokeOptions,
  RpcParams,
  RpcRequest,
  RpcResponse
} from "./types.js";

const RPC_INVOKE_CHANNEL = "desktop-el:rpc:invoke";
const RPC_EVENT_CHANNEL = "desktop-el:rpc:event";
const RPC_CANCEL_CHANNEL = "desktop-el:rpc:cancel";
const SHELL_INVOKE_CHANNEL = "desktop-el:shell:invoke";

let requestCounter = 0;

const desktopElAPI: DesktopElAPI = {
  rpc: {
    async invoke<T = unknown>(method: string, params?: RpcParams, options?: RpcInvokeOptions): Promise<T> {
      if (options?.signal?.aborted) {
        throw new RpcInvokeError({
          code: "canceled",
          message: "request canceled"
        });
      }

      const request: RpcRequest = {
        type: "request",
        id: createRequestID(),
        method,
        params
      };
      if (typeof options?.timeoutMs === "number" && options.timeoutMs > 0) {
        request.timeout_ms = options.timeoutMs;
      }

      const abortHandler = () => {
        ipcRenderer.send(RPC_CANCEL_CHANNEL, { id: request.id });
      };

      options?.signal?.addEventListener("abort", abortHandler, { once: true });

      try {
        const response = await ipcRenderer.invoke(RPC_INVOKE_CHANNEL, request);
        return unwrapRendererResponse<T>(response as RpcResponse);
      } finally {
        options?.signal?.removeEventListener("abort", abortHandler);
      }
    },
    onEvent(listener: (event: RpcEvent) => void): () => void {
      const wrapped = (_event: Electron.IpcRendererEvent, payload: RpcEvent) => {
        listener(payload);
      };

      ipcRenderer.on(RPC_EVENT_CHANNEL, wrapped);
      return () => {
        ipcRenderer.off(RPC_EVENT_CHANNEL, wrapped);
      };
    }
  },
  app: {
    getVersion(): Promise<string> {
      return invokeShell("app", "getVersion");
    },
    quit(): Promise<void> {
      return invokeShell("app", "quit");
    }
  },
  window: {
    show(): Promise<void> {
      return invokeShell("window", "show");
    },
    hide(): Promise<void> {
      return invokeShell("window", "hide");
    },
    focus(): Promise<void> {
      return invokeShell("window", "focus");
    },
    setTitle(title: string): Promise<void> {
      return invokeShell("window", "setTitle", { title });
    }
  },
  dialog: {
    open(options?: DesktopDialogOpenOptions): Promise<DesktopDialogOpenResult> {
      return invokeShell("dialog", "open", { options });
    },
    save(options?: DesktopDialogSaveOptions): Promise<DesktopDialogSaveResult> {
      return invokeShell("dialog", "save", { options });
    }
  },
  notification: {
    isSupported(): Promise<boolean> {
      return invokeShell("notification", "isSupported");
    },
    show(payload: DesktopNotificationPayload): Promise<void> {
      return invokeShell("notification", "show", { payload });
    }
  },
  file: {
    saveFromURL(options) {
      return invokeShell("file", "saveFromURL", { options });
    },
    getCachedPath(options) {
      return invokeShell("file", "getCachedPath", { options });
    },
    cacheFromURL(options) {
      return invokeShell("file", "cacheFromURL", { options });
    },
    openPath(path: string): Promise<void> {
      return invokeShell("file", "openPath", { path });
    }
  }
};

contextBridge.exposeInMainWorld("desktopEl", desktopElAPI);

declare global {
  interface Window {
    desktopEl: DesktopElAPI;
  }
}

class RpcInvokeError extends Error {
  readonly code: string;

  constructor(error: RpcError) {
    super(error.message);
    this.name = "RpcInvokeError";
    this.code = error.code;
  }
}

const createRequestID = (): string => {
  requestCounter += 1;
  return `renderer-${Date.now()}-${requestCounter}`;
};

const invokeShell = <T,>(
  namespace: "app" | "window" | "dialog" | "notification" | "file",
  method: string,
  params?: Record<string, unknown>
): Promise<T> => {
  return ipcRenderer.invoke(SHELL_INVOKE_CHANNEL, {
    namespace,
    method,
    params
  }) as Promise<T>;
};

const unwrapRendererResponse = <T,>(response: RpcResponse): T => {
  if (response.type !== "response" || typeof response.id !== "string") {
    throw new RpcInvokeError({
      code: "internal",
      message: "invalid response from main process"
    });
  }
  if (response.error) {
    throw new RpcInvokeError(response.error);
  }
  return response.result as T;
};
