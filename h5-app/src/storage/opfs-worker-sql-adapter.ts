import type { SqlAdapter, SqlRow, SqlTransactionWork, SqlValue } from './sql-adapter';

type WorkerRequestType = 'open' | 'execute' | 'query' | 'close';

interface WorkerRequest {
  id: number;
  type: WorkerRequestType;
  databaseName?: string;
  sql?: string;
  params?: readonly SqlValue[];
}

interface WorkerResponse {
  id: number;
  ok: boolean;
  rows?: SqlRow[];
  error?: string;
}

const OPFS_WORKER_TIMEOUT_MS = 15_000;

export class OpfsWorkerSqlAdapter implements SqlAdapter {
  private nextId = 1;
  private closed = false;
  private operationChain: Promise<unknown> = Promise.resolve();

  private constructor(private readonly worker: Worker) {}

  static async create(databaseName = 'redcode-h5.db'): Promise<OpfsWorkerSqlAdapter> {
    if (typeof Worker === 'undefined') {
      throw new Error('Web Worker is not available');
    }
    const worker = new Worker(new URL('./wa-sqlite-opfs.worker.ts', import.meta.url), {
      type: 'module',
      name: 'redcode-h5-sqlite-opfs',
    });
    const adapter = new OpfsWorkerSqlAdapter(worker);
    try {
      await adapter.request({ type: 'open', databaseName }, OPFS_WORKER_TIMEOUT_MS);
      return adapter;
    } catch (error) {
      worker.terminate();
      throw error;
    }
  }

  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    await this.enqueue(() => this.executeDirect(sql, params));
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    return this.enqueue(() => this.queryDirect<T>(sql, params));
  }

  async transaction<T>(work: SqlTransactionWork<T>): Promise<T> {
    return this.enqueue(() => this.runTransaction(work));
  }

  async close(): Promise<void> {
    if (this.closed) return;
    await this.enqueue(async () => {
      if (this.closed) return;
      try {
        await this.request({ type: 'close' });
      } finally {
        this.closed = true;
        this.worker.terminate();
      }
    });
  }

  private async executeDirect(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    await this.request({ type: 'execute', sql, params });
  }

  private async queryDirect<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    const response = await this.request({ type: 'query', sql, params });
    return (response.rows ?? []) as T[];
  }

  private async runTransaction<T>(work: SqlTransactionWork<T>): Promise<T> {
    const scoped = this.createTransactionAdapter();
    await this.executeDirect('BEGIN TRANSACTION');
    try {
      const result = await work(scoped);
      await this.executeDirect('COMMIT');
      return result;
    } catch (error) {
      try {
        await this.executeDirect('ROLLBACK');
      } catch (rollbackError) {
        console.warn('[h5-app] OPFS worker transaction rollback failed', rollbackError);
      }
      throw error;
    }
  }

  private createTransactionAdapter(): SqlAdapter {
    const scoped: SqlAdapter = {
      execute: (sql, params = []) => this.executeDirect(sql, params),
      query: <T = SqlRow>(sql: string, params: readonly SqlValue[] = []) => this.queryDirect<T>(sql, params),
      transaction: (work) => work(scoped),
      close: async () => undefined,
    };
    return scoped;
  }

  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const run = this.operationChain.then(operation, operation);
    this.operationChain = run.catch(() => undefined);
    return run;
  }

  private request(
    payload: Omit<WorkerRequest, 'id'>,
    timeoutMs = 30_000,
  ): Promise<WorkerResponse> {
    if (this.closed && payload.type !== 'close') {
      return Promise.reject(new Error('OPFS worker adapter is closed'));
    }
    const id = this.nextId++;
    const request: WorkerRequest = { ...payload, id };
    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        cleanup();
        reject(new Error(`OPFS worker request timed out: ${payload.type}`));
      }, timeoutMs);
      const handleMessage = (event: MessageEvent<WorkerResponse>) => {
        if (event.data?.id !== id) return;
        cleanup();
        if (event.data.ok) {
          resolve(event.data);
        } else {
          reject(new Error(event.data.error || `OPFS worker request failed: ${payload.type}`));
        }
      };
      const handleError = (event: ErrorEvent) => {
        cleanup();
        reject(event.error instanceof Error ? event.error : new Error(event.message));
      };
      const cleanup = () => {
        window.clearTimeout(timer);
        this.worker.removeEventListener('message', handleMessage);
        this.worker.removeEventListener('error', handleError);
      };
      this.worker.addEventListener('message', handleMessage);
      this.worker.addEventListener('error', handleError);
      this.worker.postMessage(request);
    });
  }
}
