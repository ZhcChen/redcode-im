import { appEnv } from '@/config/env';

import { IndexedDbSqlAdapter } from './indexeddb-sql-adapter';
import { MemorySqlAdapter } from './memory-sql-adapter';
import { OpfsWorkerSqlAdapter } from './opfs-worker-sql-adapter';
import type { SqlAdapter } from './sql-adapter';
import {
  detectBrowserStorageCapabilities,
  detectSqlFeatures,
  type BrowserStorageCapabilities,
  type StorageRuntimeReport,
} from './storage-capabilities';
import { WaSQLiteAdapter } from './wa-sqlite-adapter';

let adapterPromise: Promise<SqlAdapter> | null = null;
let runtimeReport: StorageRuntimeReport | null = null;

interface LocalDatabaseRuntime {
  mode: string;
  sqlEngine: string;
  useMockData: boolean;
}

interface LocalDatabaseFactories {
  memory: () => SqlAdapter | Promise<SqlAdapter>;
  indexedDb: () => Promise<SqlAdapter>;
  waSqliteIndexedDb: () => Promise<SqlAdapter>;
  waSqliteOpfsWorker: () => Promise<SqlAdapter>;
}

interface CreateLocalDatabaseOptions {
  capabilities?: BrowserStorageCapabilities;
  factories?: Partial<LocalDatabaseFactories>;
  runtime?: Partial<LocalDatabaseRuntime>;
}

const defaultFactories: LocalDatabaseFactories = {
  memory: () => new MemorySqlAdapter(),
  indexedDb: () => IndexedDbSqlAdapter.create(),
  waSqliteIndexedDb: () => WaSQLiteAdapter.create(),
  waSqliteOpfsWorker: () => OpfsWorkerSqlAdapter.create(),
};

export const getLocalDatabase = () => {
  if (!adapterPromise) {
    adapterPromise = createDefaultAdapter();
  }
  return adapterPromise;
};

export const getStorageRuntimeReport = () => runtimeReport;

export const resetLocalDatabaseForTests = async (adapter?: SqlAdapter) => {
  if (adapterPromise) {
    const current = await adapterPromise;
    await current.close();
  }
  adapterPromise = Promise.resolve(adapter ?? new MemorySqlAdapter());
  runtimeReport = null;
};

export const createLocalDatabaseAdapter = async (
  options: CreateLocalDatabaseOptions = {},
): Promise<SqlAdapter> => {
  const runtime: LocalDatabaseRuntime = {
    mode: options.runtime?.mode ?? import.meta.env.MODE,
    sqlEngine: options.runtime?.sqlEngine ?? appEnv.sqlEngine,
    useMockData: options.runtime?.useMockData ?? appEnv.useMockData,
  };
  const capabilities = options.capabilities ?? detectBrowserStorageCapabilities();
  const factories = { ...defaultFactories, ...options.factories };

  if (runtime.useMockData || runtime.mode === 'test') {
    const adapter = await factories.memory();
    await updateRuntimeReport(adapter, capabilities, 'memory');
    return adapter;
  }

  if (runtime.sqlEngine !== 'wa-sqlite') {
    return createIndexedDbFallback(factories, capabilities, 'VITE_H5_SQL_ENGINE 禁用 wa-sqlite');
  }

  if (capabilities.opfs) {
    try {
      const adapter = await factories.waSqliteOpfsWorker();
      await updateRuntimeReport(adapter, capabilities, 'wa-sqlite-opfs-worker');
      return adapter;
    } catch (error) {
      console.warn('[h5-app] wa-sqlite OPFS worker 初始化失败，降级到 IndexedDB VFS', error);
      return createWaSqliteIndexedDb(factories, capabilities, 'OPFS worker 初始化失败');
    }
  }

  return createWaSqliteIndexedDb(factories, capabilities, 'OPFS worker 不可用');
};

const createDefaultAdapter = () => createLocalDatabaseAdapter();

const createWaSqliteIndexedDb = async (
  factories: LocalDatabaseFactories,
  capabilities: BrowserStorageCapabilities,
  fallbackReason: string,
): Promise<SqlAdapter> => {
  try {
    const adapter = await factories.waSqliteIndexedDb();
    await updateRuntimeReport(adapter, capabilities, 'wa-sqlite-indexeddb', fallbackReason);
    return adapter;
  } catch (error) {
    console.warn('[h5-app] wa-sqlite IndexedDB VFS 初始化失败，降级到 IndexedDB 持久化 shim', error);
    return createIndexedDbFallback(factories, capabilities, 'wa-sqlite IndexedDB VFS 初始化失败');
  }
};

const createIndexedDbFallback = async (
  factories: LocalDatabaseFactories,
  capabilities: BrowserStorageCapabilities,
  fallbackReason?: string,
): Promise<SqlAdapter> => {
  if (capabilities.indexedDB) {
    try {
      const adapter = await factories.indexedDb();
      await updateRuntimeReport(adapter, capabilities, 'indexeddb-persisted', fallbackReason);
      return adapter;
    } catch (error) {
      console.warn('[h5-app] IndexedDB 持久化 shim 初始化失败，降级到内存存储', error);
    }
  }
  const adapter = await factories.memory();
  await updateRuntimeReport(adapter, capabilities, 'memory', fallbackReason ?? 'IndexedDB 不可用');
  return adapter;
};

const updateRuntimeReport = async (
  adapter: SqlAdapter,
  browser: BrowserStorageCapabilities,
  selectedBackend: string,
  fallbackReason?: string,
) => {
  runtimeReport = {
    browser,
    sql: await detectSqlFeatures(adapter),
    selectedBackend,
    fallbackReason,
  };
};
