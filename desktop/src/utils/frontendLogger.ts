import { invoke } from '@tauri-apps/api/core';

type FrontendLogLevel = 'debug' | 'info' | 'warn' | 'error';

interface FrontendLogPayload {
  log_tag: string;
  level: FrontendLogLevel;
  message?: string;
  data?: unknown;
  ts: string;
}

function isTauriRuntime(): boolean {
  return typeof window !== 'undefined' && Boolean(
    (window as any).__TAURI_INTERNALS__ ||
    (window as any).__TAURI_IPC__ ||
    (window as any).__TAURI__
  );
}

async function sendToRust(payload: FrontendLogPayload): Promise<void> {
  if (!isTauriRuntime()) return;
  try {
    await invoke('client_debug', { payload });
  } catch {
    // 静默失败，避免影响主流程
  }
}

export async function logFrontend(
  tag: string,
  level: FrontendLogLevel,
  message: string,
  data?: unknown,
): Promise<void> {
  const ts = new Date().toISOString();
  const prefix = `[${tag}]`;

  // 浏览器控制台输出，便于本地调试
  const args = data !== undefined ? [prefix, message, data] : [prefix, message];
  switch (level) {
    case 'debug':
      console.debug(...args);
      break;
    case 'info':
      console.info(...args);
      break;
    case 'warn':
      console.warn(...args);
      break;
    case 'error':
      console.error(...args);
      break;
  }

  // 通过 IPC 将日志发送到 Rust 侧，写入本地日志文件
  void sendToRust({
    log_tag: tag,
    level,
    message,
    data,
    ts,
  });
}

export function logDebug(tag: string, message: string, data?: unknown): void {
  void logFrontend(tag, 'debug', message, data);
}

export function logInfo(tag: string, message: string, data?: unknown): void {
  void logFrontend(tag, 'info', message, data);
}

export function logWarn(tag: string, message: string, data?: unknown): void {
  void logFrontend(tag, 'warn', message, data);
}

export function logError(tag: string, message: string, data?: unknown): void {
  void logFrontend(tag, 'error', message, data);
}

