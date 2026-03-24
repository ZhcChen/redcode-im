import { contextBridge, ipcRenderer } from "electron";
import {
  RPC_CANCEL_CHANNEL,
  RPC_EVENT_CHANNEL,
  RPC_INVOKE_CHANNEL,
  type DesktopElAPI,
  type RpcError,
  type RpcEvent,
  type RpcInvokeOptions,
  type RpcParams,
  type RpcRequest,
  type RpcResponse
} from "./types.js";

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

const unwrapRendererResponse = <T>(response: RpcResponse): T => {
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
