import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { join } from "node:path";
import { createInterface, type Interface as ReadlineInterface } from "node:readline";
import type { RpcEvent, RpcRequest, RpcResponse } from "../preload/types.js";
import type { RpcTransport } from "./rpc.js";

export interface GoCoreBridgeOptions {
  binaryPath?: string;
  command?: string;
  args?: string[];
  cwd?: string;
}

interface PendingRequest {
  resolve: (response: RpcResponse) => void;
  reject: (error: Error) => void;
  abortHandler?: () => void;
}

type ExitListener = (code: number | null, signal: NodeJS.Signals | null) => void;

export class GoCoreBridge implements RpcTransport {
  private readonly eventListeners = new Set<(event: RpcEvent) => void>();
  private readonly exitListeners = new Set<ExitListener>();
  private readonly pendingRequests = new Map<string, PendingRequest>();

  private process?: ChildProcessWithoutNullStreams;
  private stdoutLines?: ReadlineInterface;
  private stderrLines?: ReadlineInterface;
  private readyPromise?: Promise<void>;
  private resolveReady?: () => void;
  private rejectReady?: (error: Error) => void;
  private ready = false;
  private stopping = false;

  readonly binaryPath?: string;
  readonly command?: string;
  readonly args: string[];
  readonly cwd: string;

  constructor(options: GoCoreBridgeOptions = {}) {
    this.binaryPath = options.binaryPath;
    this.command = options.command;
    this.args = options.args ?? [];
    this.cwd = options.cwd ?? join(process.cwd(), "go-core");
  }

  async start(): Promise<void> {
    if (this.ready) {
      return;
    }
    if (this.readyPromise) {
      return this.readyPromise;
    }

    this.stopping = false;
    this.readyPromise = new Promise<void>((resolve, reject) => {
      this.resolveReady = resolve;
      this.rejectReady = reject;
    });

    const { command, args } = this.resolveSpawnCommand();
    const child = spawn(command, args, {
      cwd: this.cwd,
      stdio: ["pipe", "pipe", "pipe"]
    });

    this.process = child;
    this.stdoutLines = createInterface({ input: child.stdout });
    this.stderrLines = createInterface({ input: child.stderr });

    this.stdoutLines.on("line", (line) => {
      this.handleStdoutLine(line);
    });
    this.stderrLines.on("line", (line) => {
      this.logStderrLine(line);
    });

    child.once("error", (error) => {
      this.handleProcessFailure(error);
    });
    child.once("exit", (code, signal) => {
      this.handleExit(code, signal);
    });

    return this.readyPromise;
  }

  async stop(): Promise<void> {
    this.stopping = true;
    const child = this.process;
    if (!child) {
      this.cleanupState();
      return;
    }

    const exitPromise = new Promise<void>((resolve) => {
      child.once("exit", () => resolve());
    });

    child.kill("SIGTERM");
    await exitPromise;
  }

  async send(request: RpcRequest, signal?: AbortSignal): Promise<RpcResponse> {
    if (signal?.aborted) {
      return this.toCanceledResponse(request.id);
    }

    await this.start();
    const child = this.process;
    if (!child?.stdin.writable) {
      return {
        type: "response",
        id: request.id,
        error: {
          code: "internal",
          message: "go-core stdio bridge is not connected"
        }
      };
    }

    return new Promise<RpcResponse>((resolve, reject) => {
      const pending: PendingRequest = {
        resolve: (response) => {
          signal?.removeEventListener("abort", pending.abortHandler as () => void);
          resolve(response);
        },
        reject: (error) => {
          signal?.removeEventListener("abort", pending.abortHandler as () => void);
          reject(error);
        }
      };

      if (signal) {
        pending.abortHandler = () => {
          this.pendingRequests.delete(request.id);
          resolve(this.toCanceledResponse(request.id));
        };
        signal.addEventListener("abort", pending.abortHandler, { once: true });
      }

      this.pendingRequests.set(request.id, pending);

      child.stdin.write(`${JSON.stringify(request)}\n`, (error) => {
        if (!error) {
          return;
        }
        this.pendingRequests.delete(request.id);
        pending.reject(error);
      });
    });
  }

  onEvent(listener: (event: RpcEvent) => void): () => void {
    this.eventListeners.add(listener);
    return () => {
      this.eventListeners.delete(listener);
    };
  }

  onExit(listener: ExitListener): () => void {
    this.exitListeners.add(listener);
    return () => {
      this.exitListeners.delete(listener);
    };
  }

  dispose(): void {
    void this.stop();
  }

  logStderrLine(line: string): void {
    console.warn(`[go-core] ${line}`);
  }

  private resolveSpawnCommand(): { command: string; args: string[] } {
    if (this.command) {
      return {
        command: this.command,
        args: this.args
      };
    }
    if (this.binaryPath) {
      return {
        command: this.binaryPath,
        args: this.args
      };
    }
    return {
      command: "go",
      args: ["run", "./cmd/desktop-el-core", ...this.args]
    };
  }

  private handleStdoutLine(line: string): void {
    let message: RpcEvent | RpcResponse;
    try {
      message = JSON.parse(line) as RpcEvent | RpcResponse;
    } catch (error) {
      this.handleProcessFailure(error instanceof Error ? error : new Error(String(error)));
      return;
    }

    if (message.type === "event") {
      if (message.event === "core.ready" && !this.ready) {
        this.ready = true;
        this.resolveReady?.();
        this.resolveReady = undefined;
        this.rejectReady = undefined;
      }
      for (const listener of this.eventListeners) {
        listener(message);
      }
      return;
    }

    if (message.type !== "response" || typeof message.id !== "string") {
      this.handleProcessFailure(new Error("invalid rpc message from go-core"));
      return;
    }

    const pending = this.pendingRequests.get(message.id);
    if (!pending) {
      return;
    }

    this.pendingRequests.delete(message.id);
    pending.resolve(message);
  }

  private handleProcessFailure(error: Error): void {
    if (!this.ready) {
      this.rejectReady?.(error);
      this.resolveReady = undefined;
      this.rejectReady = undefined;
      this.readyPromise = undefined;
    }

    for (const [id, pending] of this.pendingRequests) {
      this.pendingRequests.delete(id);
      pending.reject(error);
    }

    if (!this.stopping) {
      this.process?.kill("SIGTERM");
    }
  }

  private handleExit(code: number | null, signal: NodeJS.Signals | null): void {
    const error = this.stopping
      ? null
      : new Error(`go-core exited unexpectedly (code=${code ?? "null"}, signal=${signal ?? "null"})`);

    if (error) {
      this.handleProcessFailure(error);
    }

    this.cleanupState();

    for (const listener of this.exitListeners) {
      listener(code, signal);
    }
  }

  private cleanupState(): void {
    this.process = undefined;
    this.stdoutLines?.close();
    this.stderrLines?.close();
    this.stdoutLines = undefined;
    this.stderrLines = undefined;
    this.ready = false;
    this.readyPromise = undefined;
    this.resolveReady = undefined;
    this.rejectReady = undefined;
  }

  private toCanceledResponse(id: string): RpcResponse {
    return {
      type: "response",
      id,
      error: {
        code: "canceled",
        message: "request canceled"
      }
    };
  }
}
