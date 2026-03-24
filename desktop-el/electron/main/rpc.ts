import { BrowserWindow, ipcMain } from "electron";
import { RPC_CANCEL_CHANNEL, RPC_EVENT_CHANNEL, RPC_INVOKE_CHANNEL } from "../preload/types.js";
import type {
  RpcCancelRequest,
  RpcError,
  RpcEvent,
  RpcInvokeOptions,
  RpcParams,
  RpcRequest,
  RpcResponse
} from "../preload/types.js";

export interface RpcTransport {
  send(request: RpcRequest, signal?: AbortSignal): Promise<RpcResponse>;
  onEvent(listener: (event: RpcEvent) => void): () => void;
}

export class RpcInvokeError extends Error {
  readonly code: RpcError["code"];
  readonly requestId?: string;

  constructor(error: RpcError, requestId?: string) {
    super(error.message);
    this.name = "RpcInvokeError";
    this.code = error.code;
    this.requestId = requestId;
  }
}

export class RpcDispatcher {
  private counter = 0;

  constructor(private readonly transport: RpcTransport) {}

  async invoke<T = unknown>(method: string, params?: RpcParams, options?: RpcInvokeOptions): Promise<T> {
    const request: RpcRequest = {
      type: "request",
      id: this.nextRequestID(),
      method,
      params
    };
    if (typeof options?.timeoutMs === "number" && options.timeoutMs > 0) {
      request.timeout_ms = options.timeoutMs;
    }

    return this.invokeRequest<T>(request, options?.signal);
  }

  async invokeRequest<T = unknown>(request: RpcRequest, signal?: AbortSignal): Promise<T> {
    const response = await this.transport.send(request, signal);
    return this.unwrapResponse<T>(response, request.id);
  }

  onEvent(listener: (event: RpcEvent) => void): () => void {
    return this.transport.onEvent(listener);
  }

  private unwrapResponse<T>(response: unknown, requestId: string): T {
    if (!isRpcResponse(response) || response.id !== requestId) {
      throw new RpcInvokeError(
        {
          code: "internal",
          message: "response id mismatch"
        },
        requestId
      );
    }
    if (response.error) {
      throw new RpcInvokeError(response.error, requestId);
    }

    return response.result as T;
  }

  private nextRequestID(): string {
    this.counter += 1;
    return `req-${Date.now()}-${this.counter}`;
  }
}

export const registerRpcIpc = (dispatcher: RpcDispatcher): (() => void) => {
  const pendingCancels = new Map<string, AbortController>();
  const cleanupEvent = dispatcher.onEvent((event) => {
    for (const win of BrowserWindow.getAllWindows()) {
      win.webContents.send(RPC_EVENT_CHANNEL, event);
    }
  });

  const cancelListener = (_event: Electron.IpcMainEvent, payload: unknown) => {
    if (!isRpcCancelPayload(payload)) {
      return;
    }
    pendingCancels.get(payload.id)?.abort();
  };

  ipcMain.on(RPC_CANCEL_CHANNEL, cancelListener);

  ipcMain.handle(RPC_INVOKE_CHANNEL, async (_event, payload: unknown) => {
    if (!isRpcRequest(payload)) {
      return toErrorResponse("invalid_request", "invalid invoke payload");
    }

    const controller = new AbortController();
    pendingCancels.set(payload.id, controller);

    try {
      if (process.env.VITE_DEV_SERVER_URL) {
        console.log(`[desktop-el] rpc invoke ${payload.method}`);
      }
      const result = await dispatcher.invokeRequest(payload, controller.signal);
      const response: RpcResponse = {
        type: "response",
        id: payload.id,
        result
      };
      return response;
    } catch (error) {
      if (error instanceof RpcInvokeError) {
        return toErrorResponse(error.code, error.message, payload.id);
      }
      return toErrorResponse("internal", getErrorMessage(error), payload.id);
    } finally {
      pendingCancels.delete(payload.id);
    }
  });

  return () => {
    cleanupEvent();
    pendingCancels.clear();
    ipcMain.off(RPC_CANCEL_CHANNEL, cancelListener);
    ipcMain.removeHandler(RPC_INVOKE_CHANNEL);
  };
};

const isRpcRequest = (value: unknown): value is RpcRequest => {
  if (!value || typeof value !== "object") {
    return false;
  }
  const payload = value as RpcRequest;
  return (
    payload.type === "request" &&
    typeof payload.id === "string" &&
    payload.id.length > 0 &&
    typeof payload.method === "string" &&
    payload.method.length > 0
  );
};

const isRpcResponse = (value: unknown): value is RpcResponse => {
  if (!value || typeof value !== "object") {
    return false;
  }
  const response = value as RpcResponse;
  return response.type === "response" && typeof response.id === "string";
};

const isRpcCancelPayload = (value: unknown): value is RpcCancelRequest => {
  if (!value || typeof value !== "object") {
    return false;
  }
  const payload = value as RpcCancelRequest;
  return typeof payload.id === "string" && payload.id.length > 0;
};

const toErrorResponse = (code: RpcError["code"], message: string, id = "__renderer__"): RpcResponse => ({
  type: "response",
  id,
  error: {
    code,
    message
  }
});

const getErrorMessage = (error: unknown): string => {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
};
