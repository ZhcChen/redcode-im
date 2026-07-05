import { describe, expect, it } from 'vitest';

import { createLocalDatabaseAdapter, getStorageRuntimeReport } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import type { BrowserStorageCapabilities } from '@/storage/storage-capabilities';

const fullCapabilities: BrowserStorageCapabilities = {
  worker: true,
  opfs: true,
  indexedDB: true,
  cacheApi: true,
  storageEstimate: true,
  storagePersist: true,
};

const runtime = {
  mode: 'production',
  sqlEngine: 'wa-sqlite',
  useMockData: false,
};

describe('local database adapter selection', () => {
  it('prefers wa-sqlite OPFS worker when available', async () => {
    const adapter = new MemorySqlAdapter();
    const selected = await createLocalDatabaseAdapter({
      capabilities: fullCapabilities,
      runtime,
      factories: {
        waSqliteOpfsWorker: async () => adapter,
      },
    });

    expect(selected).toBe(adapter);
    expect(getStorageRuntimeReport()).toMatchObject({
      selectedBackend: 'wa-sqlite-opfs-worker',
      browser: expect.objectContaining({ opfs: true, indexedDB: true }),
      sql: { fts5: true },
    });
  });

  it('falls back to wa-sqlite IndexedDB VFS when OPFS worker fails', async () => {
    const adapter = new MemorySqlAdapter();
    const selected = await createLocalDatabaseAdapter({
      capabilities: fullCapabilities,
      runtime,
      factories: {
        waSqliteOpfsWorker: async () => {
          throw new Error('opfs denied');
        },
        waSqliteIndexedDb: async () => adapter,
      },
    });

    expect(selected).toBe(adapter);
    expect(getStorageRuntimeReport()).toMatchObject({
      selectedBackend: 'wa-sqlite-indexeddb',
      fallbackReason: 'OPFS worker 初始化失败',
    });
  });

  it('uses IndexedDB persistence when wa-sqlite is disabled', async () => {
    const adapter = new MemorySqlAdapter();
    const selected = await createLocalDatabaseAdapter({
      capabilities: fullCapabilities,
      runtime: { ...runtime, sqlEngine: 'indexeddb' },
      factories: {
        indexedDb: async () => adapter,
      },
    });

    expect(selected).toBe(adapter);
    expect(getStorageRuntimeReport()).toMatchObject({
      selectedBackend: 'indexeddb-persisted',
      fallbackReason: 'VITE_H5_SQL_ENGINE 禁用 wa-sqlite',
    });
  });

  it('falls back to memory when persistent browser storage is unavailable', async () => {
    const adapter = new MemorySqlAdapter();
    const selected = await createLocalDatabaseAdapter({
      capabilities: {
        ...fullCapabilities,
        opfs: false,
        indexedDB: false,
      },
      runtime,
      factories: {
        memory: () => adapter,
        waSqliteIndexedDb: async () => {
          throw new Error('idb unavailable');
        },
      },
    });

    expect(selected).toBe(adapter);
    expect(getStorageRuntimeReport()).toMatchObject({
      selectedBackend: 'memory',
      fallbackReason: 'wa-sqlite IndexedDB VFS 初始化失败',
    });
  });
});
