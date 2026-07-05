import { afterEach, describe, expect, it, vi } from 'vitest';

import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { detectBrowserStorageCapabilities, detectSqlFeatures } from '@/storage/storage-capabilities';
import type { SqlAdapter, SqlRow, SqlValue } from '@/storage/sql-adapter';

describe('storage capability probes', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('detects OPFS, IndexedDB and Cache API browser capabilities', () => {
    vi.stubGlobal('Worker', class MockWorker {});
    vi.stubGlobal('indexedDB', {});
    vi.stubGlobal('caches', { open: vi.fn() });
    vi.stubGlobal('navigator', {
      storage: {
        getDirectory: vi.fn(),
        estimate: vi.fn(),
        persist: vi.fn(),
      },
    });

    expect(detectBrowserStorageCapabilities()).toEqual({
      worker: true,
      opfs: true,
      indexedDB: true,
      cacheApi: true,
      storageEstimate: true,
      storagePersist: true,
    });
  });

  it('reports FTS5 support when CREATE VIRTUAL TABLE succeeds', async () => {
    await expect(detectSqlFeatures(new MemorySqlAdapter())).resolves.toEqual({ fts5: true });
  });

  it('reports FTS5 unavailable when the adapter rejects fts5 virtual tables', async () => {
    await expect(detectSqlFeatures(new FtsRejectingAdapter())).resolves.toEqual({ fts5: false });
  });
});

class FtsRejectingAdapter extends MemorySqlAdapter implements SqlAdapter {
  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    if (sql.toLowerCase().includes('using fts5')) {
      throw new Error('fts disabled');
    }
    return super.execute(sql, params);
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    return super.query<T>(sql, params);
  }
}
