import type { RpcEvent, RpcRequest, RpcResponse } from "../preload/types.js";
import type { RpcTransport } from "./rpc.js";

export interface GoCoreBridgeOptions {
  binaryPath?: string;
  args?: string[];
}

export class GoCoreBridge implements RpcTransport {
  private readonly eventListeners = new Set<(event: RpcEvent) => void>();

  readonly binaryPath?: string;
  readonly args: string[];

  constructor(options: GoCoreBridgeOptions = {}) {
    this.binaryPath = options.binaryPath;
    this.args = options.args ?? [];
  }

  async send(request: RpcRequest, signal?: AbortSignal): Promise<RpcResponse> {
    if (signal?.aborted) {
      return {
        type: "response",
        id: request.id,
        error: {
          code: "canceled",
          message: "request canceled"
        }
      };
    }

    return {
      type: "response",
      id: request.id,
      error: {
        code: "internal",
        message: "go-core stdio bridge is not connected yet"
      }
    };
  }

  onEvent(listener: (event: RpcEvent) => void): () => void {
    this.eventListeners.add(listener);
    return () => {
      this.eventListeners.delete(listener);
    };
  }

  emitEvent(event: RpcEvent): void {
    for (const listener of this.eventListeners) {
      listener(event);
    }
  }

  logStderrLine(line: string): void {
    console.warn(`[go-core] ${line}`);
  }

  dispose(): void {
    this.eventListeners.clear();
  }
}
