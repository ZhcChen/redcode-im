import type { SqlAdapter, SqlRow, SqlTransactionWork, SqlValue } from './sql-adapter';

interface WaSQLiteApi {
  open_v2(name: string, flags?: number, vfs?: string): Promise<number>;
  exec(db: number, sql: string, callback?: (row: SqlValue[], columns: string[]) => void): Promise<number>;
  execWithParams?(db: number, sql: string, params: readonly SqlValue[]): Promise<{ columns: string[]; rows: SqlValue[][] }>;
  close(db: number): Promise<number>;
  vfs_register(vfs: { name: string }, makeDefault?: boolean): number;
}

interface WaSQLiteFactoryModule {
  default: () => Promise<unknown>;
}

interface WaSQLiteApiModule {
  Factory: (module: unknown) => WaSQLiteApi;
}

export class WaSQLiteAdapter implements SqlAdapter {
  private db: number | null = null;
  private vfs: { close?: () => Promise<void>; name: string } | null = null;
  private operationChain: Promise<unknown> = Promise.resolve();

  private constructor(
    private readonly sqlite: WaSQLiteApi,
    private readonly databaseName: string,
  ) {}

  static async create(databaseName = 'redcode-h5.db', idbName = 'redcode-h5-sqlite'): Promise<WaSQLiteAdapter> {
    const [factoryModule, sqliteModule] = await Promise.all([
      import('wa-sqlite/dist/wa-sqlite-async.mjs') as Promise<WaSQLiteFactoryModule>,
      import('wa-sqlite'),
    ]);
    const module = await factoryModule.default();
    const sqlite = (sqliteModule as unknown as WaSQLiteApiModule).Factory(module);
    try {
      const adapter = new WaSQLiteAdapter(sqlite, databaseName);
      await adapter.openWithIndexedDb(idbName);
      return adapter;
    } catch (error) {
      console.warn('[h5-app] wa-sqlite IndexedDB 打开失败，清理后重试', error);
      await deleteIndexedDb(idbName);
      const adapter = new WaSQLiteAdapter(sqlite, databaseName);
      await adapter.openWithIndexedDb(idbName);
      return adapter;
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
    await this.enqueue(async () => {
      if (this.db !== null) {
        await this.sqlite.close(this.db);
        this.db = null;
      }
      await this.vfs?.close?.();
      this.vfs = null;
    });
  }

  private async executeDirect(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    const db = this.requireDb();
    if (params.length > 0 && this.sqlite.execWithParams) {
      await this.sqlite.execWithParams(db, sql, params);
      return;
    }
    await this.sqlite.exec(db, sql);
  }

  private async queryDirect<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    const db = this.requireDb();
    if (this.sqlite.execWithParams) {
      const result = await this.sqlite.execWithParams(db, sql, params);
      return result.rows.map((row) => rowToObject<T>(result.columns, row));
    }

    const rows: T[] = [];
    await this.sqlite.exec(db, sql, (row, columns) => {
      rows.push(rowToObject<T>(columns, row));
    });
    return rows;
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
        console.warn('[h5-app] wa-sqlite transaction rollback failed', rollbackError);
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

  private requireDb() {
    if (this.db === null) {
      throw new Error('wa-sqlite database is not open');
    }
    return this.db;
  }

  private async openWithIndexedDb(idbName: string) {
    const { IDBBatchAtomicVFS } = await import('wa-sqlite/src/examples/IDBBatchAtomicVFS.js');
    this.vfs = new IDBBatchAtomicVFS(idbName, { durability: 'relaxed' });
    this.sqlite.vfs_register(this.vfs, false);
    this.db = await this.sqlite.open_v2(this.databaseName, 0x06, this.vfs.name);
    await this.configureConnection();
  }

  private async configureConnection() {
    const db = this.requireDb();
    // Client-side cache can use an in-memory rollback journal. This avoids
    // IDBBatchAtomicVFS trying to open transient "*-journal" files in IndexedDB.
    await this.sqlite.exec(db, `
      PRAGMA journal_mode=MEMORY;
      PRAGMA temp_store=MEMORY;
      PRAGMA cache_size=-2000;
      PRAGMA synchronous=NORMAL;
    `);
  }
}

const deleteIndexedDb = async (idbName: string) => {
  if (typeof indexedDB === 'undefined') return;
  await new Promise<void>((resolve) => {
    const request = indexedDB.deleteDatabase(idbName);
    request.addEventListener('success', () => resolve());
    request.addEventListener('error', () => resolve());
    request.addEventListener('blocked', () => resolve());
  });
};

const rowToObject = <T>(columns: string[], row: SqlValue[]) => {
  const record: SqlRow = {};
  columns.forEach((column, index) => {
    record[column] = row[index] ?? null;
  });
  return record as unknown as T;
};
