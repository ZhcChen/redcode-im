import type { SqlAdapter } from './sql-adapter';

export interface BrowserStorageCapabilities {
  worker: boolean;
  opfs: boolean;
  indexedDB: boolean;
  cacheApi: boolean;
  storageEstimate: boolean;
  storagePersist: boolean;
}

export interface SqlFeatureCapabilities {
  fts5: boolean;
}

export interface StorageRuntimeReport {
  browser: BrowserStorageCapabilities;
  sql: SqlFeatureCapabilities;
  selectedBackend: string;
  fallbackReason?: string;
}

export const detectBrowserStorageCapabilities = (): BrowserStorageCapabilities => {
  const nav = typeof navigator === 'undefined' ? undefined : navigator;
  const storage = nav?.storage;
  return {
    worker: typeof Worker !== 'undefined',
    opfs: typeof Worker !== 'undefined' && typeof storage?.getDirectory === 'function',
    indexedDB: typeof indexedDB !== 'undefined',
    cacheApi: typeof caches !== 'undefined' && typeof caches.open === 'function',
    storageEstimate: typeof storage?.estimate === 'function',
    storagePersist: typeof storage?.persist === 'function',
  };
};

export const detectSqlFeatures = async (adapter: SqlAdapter): Promise<SqlFeatureCapabilities> => {
  const probeName = `redcode_fts_probe_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  try {
    await adapter.execute(`CREATE VIRTUAL TABLE ${probeName} USING fts5(content)`);
    await adapter.execute(`DROP TABLE IF EXISTS ${probeName}`);
    return { fts5: true };
  } catch {
    try {
      await adapter.execute(`DROP TABLE IF EXISTS ${probeName}`);
    } catch {
      // Ignore cleanup failures from adapters that do not support FTS5.
    }
    return { fts5: false };
  }
};
