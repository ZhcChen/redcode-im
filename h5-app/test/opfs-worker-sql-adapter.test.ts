import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { OpfsWorkerSqlAdapter } from '@/storage/opfs-worker-sql-adapter';

interface RecordedRequest {
  id: number;
  type: 'open' | 'execute' | 'query' | 'close';
  databaseName?: string;
  sql?: string;
}

class RecordingWorker {
  static requests: RecordedRequest[] = [];
  static failOpen = false;
  static terminated = 0;

  private readonly listeners = new Set<(event: MessageEvent) => void>();

  constructor(
    readonly url: URL,
    readonly options?: WorkerOptions,
  ) {}

  addEventListener(type: string, listener: EventListenerOrEventListenerObject) {
    if (type !== 'message') return;
    this.listeners.add(listener as (event: MessageEvent) => void);
  }

  removeEventListener(type: string, listener: EventListenerOrEventListenerObject) {
    if (type !== 'message') return;
    this.listeners.delete(listener as (event: MessageEvent) => void);
  }

  postMessage(request: RecordedRequest) {
    RecordingWorker.requests.push({ ...request });
    window.setTimeout(() => {
      for (const listener of this.listeners) {
        listener(new MessageEvent('message', {
          data: {
            id: request.id,
            ok: !(RecordingWorker.failOpen && request.type === 'open'),
            error: RecordingWorker.failOpen && request.type === 'open' ? 'open failed' : undefined,
            rows: request.type === 'query' ? [] : undefined,
          },
        }));
      }
    }, 0);
  }

  terminate() {
    RecordingWorker.terminated += 1;
  }
}

describe('OpfsWorkerSqlAdapter', () => {
  beforeEach(() => {
    RecordingWorker.requests = [];
    RecordingWorker.failOpen = false;
    RecordingWorker.terminated = 0;
    vi.stubGlobal('Worker', RecordingWorker);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('runs nested transaction work without issuing nested BEGIN statements', async () => {
    const adapter = await OpfsWorkerSqlAdapter.create('test.db');
    RecordingWorker.requests = [];

    await adapter.transaction(async (tx) => {
      await tx.execute('INSERT outer');
      await tx.transaction(async (nested) => {
        await nested.execute('INSERT nested');
      });
    });

    expect(executedSql()).toEqual([
      'BEGIN TRANSACTION',
      'INSERT outer',
      'INSERT nested',
      'COMMIT',
    ]);
  });

  it('terminates the worker when opening OPFS fails', async () => {
    RecordingWorker.failOpen = true;

    await expect(OpfsWorkerSqlAdapter.create('test.db')).rejects.toThrow('open failed');

    expect(RecordingWorker.terminated).toBe(1);
  });

  it('queues concurrent transactions so their BEGIN/COMMIT blocks cannot interleave', async () => {
    const adapter = await OpfsWorkerSqlAdapter.create('test.db');
    RecordingWorker.requests = [];

    const first = adapter.transaction(async (tx) => {
      await delay(5);
      await tx.execute('INSERT first');
    });
    const second = adapter.transaction(async (tx) => {
      await tx.execute('INSERT second');
    });

    await Promise.all([first, second]);

    expect(executedSql()).toEqual([
      'BEGIN TRANSACTION',
      'INSERT first',
      'COMMIT',
      'BEGIN TRANSACTION',
      'INSERT second',
      'COMMIT',
    ]);
  });
});

const executedSql = () => RecordingWorker.requests
  .filter((request) => request.type === 'execute')
  .map((request) => request.sql);

const delay = (ms: number) => new Promise((resolve) => {
  window.setTimeout(resolve, ms);
});
