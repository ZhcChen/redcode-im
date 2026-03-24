export type RpcMessageType = "request" | "response" | "event";

export type RpcErrorCode =
  | "parse_error"
  | "invalid_request"
  | "method_not_found"
  | "invalid_params"
  | "internal"
  | "timeout"
  | "canceled";

export interface RpcError {
  code: RpcErrorCode;
  message: string;
}

export type RpcParams = Record<string, unknown> | unknown[] | null;

export interface RpcRequest {
  type: "request";
  id: string;
  method: string;
  params?: RpcParams;
  timeout_ms?: number;
}

export interface RpcCancelRequest {
  id: string;
}

export interface RpcResponse {
  type: "response";
  id: string;
  result?: unknown;
  error?: RpcError;
}

export interface RpcEvent {
  type: "event";
  event: string;
  data?: unknown;
}

export interface RpcInvokeOptions {
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface RpcAPI {
  invoke<T = unknown>(method: string, params?: RpcParams, options?: RpcInvokeOptions): Promise<T>;
  onEvent(listener: (event: RpcEvent) => void): () => void;
}

export interface DesktopElAPI {
  rpc: RpcAPI;
}

export const RPC_INVOKE_CHANNEL = "desktop-el:rpc:invoke";
export const RPC_EVENT_CHANNEL = "desktop-el:rpc:event";
export const RPC_CANCEL_CHANNEL = "desktop-el:rpc:cancel";
