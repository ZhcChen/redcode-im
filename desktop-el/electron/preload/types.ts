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

export interface DesktopDialogFilter {
  name: string;
  extensions: string[];
}

export type DesktopDialogProperty =
  | "openFile"
  | "openDirectory"
  | "multiSelections"
  | "showHiddenFiles"
  | "createDirectory"
  | "promptToCreate";

export interface DesktopDialogOpenOptions {
  title?: string;
  defaultPath?: string;
  buttonLabel?: string;
  filters?: DesktopDialogFilter[];
  properties?: DesktopDialogProperty[];
}

export interface DesktopDialogOpenResult {
  canceled: boolean;
  filePaths: string[];
}

export interface DesktopDialogSaveOptions {
  title?: string;
  defaultPath?: string;
  buttonLabel?: string;
  filters?: DesktopDialogFilter[];
}

export interface DesktopDialogSaveResult {
  canceled: boolean;
  filePath?: string;
}

export interface DesktopNotificationPayload {
  title: string;
  body?: string;
  silent?: boolean;
}

export interface DesktopFileSaveFromURLOptions {
  url: string;
  filePath: string;
}

export interface DesktopFileSaveFromURLResult {
  filePath: string;
}

export interface DesktopFileCachePathOptions {
  relativePath: string;
}

export interface DesktopFileCachePathResult {
  filePath: string;
  fileUrl: string;
}

export interface DesktopFileCacheFromURLOptions {
  url: string;
  relativePath: string;
}

export interface DesktopAppAPI {
  getVersion(): Promise<string>;
  quit(): Promise<void>;
}

export interface DesktopWindowAPI {
  show(): Promise<void>;
  hide(): Promise<void>;
  focus(): Promise<void>;
  setTitle(title: string): Promise<void>;
}

export interface DesktopDialogAPI {
  open(options?: DesktopDialogOpenOptions): Promise<DesktopDialogOpenResult>;
  save(options?: DesktopDialogSaveOptions): Promise<DesktopDialogSaveResult>;
}

export interface DesktopNotificationAPI {
  isSupported(): Promise<boolean>;
  show(payload: DesktopNotificationPayload): Promise<void>;
}

export interface DesktopFileAPI {
  saveFromURL(options: DesktopFileSaveFromURLOptions): Promise<DesktopFileSaveFromURLResult>;
  getCachedPath(options: DesktopFileCachePathOptions): Promise<DesktopFileCachePathResult | null>;
  cacheFromURL(options: DesktopFileCacheFromURLOptions): Promise<DesktopFileCachePathResult>;
  openPath(path: string): Promise<void>;
}

export type ShellNamespace = "app" | "window" | "dialog" | "notification" | "file";

export interface ShellInvokePayload {
  namespace: ShellNamespace;
  method: string;
  params?: Record<string, unknown>;
}

export interface DesktopElAPI {
  rpc: RpcAPI;
  app: DesktopAppAPI;
  window: DesktopWindowAPI;
  dialog: DesktopDialogAPI;
  notification: DesktopNotificationAPI;
  file: DesktopFileAPI;
}

export const RPC_INVOKE_CHANNEL = "desktop-el:rpc:invoke";
export const RPC_EVENT_CHANNEL = "desktop-el:rpc:event";
export const RPC_CANCEL_CHANNEL = "desktop-el:rpc:cancel";
export const SHELL_INVOKE_CHANNEL = "desktop-el:shell:invoke";
