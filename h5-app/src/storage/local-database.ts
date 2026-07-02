import { appEnv } from '@/config/env';

import { IndexedDbSqlAdapter } from './indexeddb-sql-adapter';
import { MemorySqlAdapter } from './memory-sql-adapter';
import type { SqlAdapter } from './sql-adapter';
import { WaSQLiteAdapter } from './wa-sqlite-adapter';

let adapterPromise: Promise<SqlAdapter> | null = null;

export const getLocalDatabase = () => {
  if (!adapterPromise) {
    adapterPromise = createDefaultAdapter();
  }
  return adapterPromise;
};

export const resetLocalDatabaseForTests = async (adapter?: SqlAdapter) => {
  if (adapterPromise) {
    const current = await adapterPromise;
    await current.close();
  }
  adapterPromise = Promise.resolve(adapter ?? new MemorySqlAdapter());
};

const createDefaultAdapter = async (): Promise<SqlAdapter> => {
  if (appEnv.useMockData || import.meta.env.MODE === 'test') {
    return new MemorySqlAdapter();
  }
  if (appEnv.sqlEngine !== 'wa-sqlite') {
    return IndexedDbSqlAdapter.create();
  }
  try {
    return await WaSQLiteAdapter.create();
  } catch (error) {
    console.warn('[h5-app] wa-sqlite 初始化失败，降级到内存存储', error);
    return new MemorySqlAdapter();
  }
};
