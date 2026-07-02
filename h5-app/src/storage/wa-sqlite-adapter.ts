import type { SqlAdapter, SqlRow, SqlValue } from './sql-adapter';

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
    const adapter = new WaSQLiteAdapter(sqlite, databaseName);
    await adapter.openWithIndexedDb(idbName);
    return adapter;
  }

  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    const db = this.requireDb();
    if (params.length > 0 && this.sqlite.execWithParams) {
      await this.sqlite.execWithParams(db, sql, params);
      return;
    }
    await this.sqlite.exec(db, sql);
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
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

  async transaction<T>(work: () => Promise<T>): Promise<T> {
    await this.execute('BEGIN TRANSACTION');
    try {
      const result = await work();
      await this.execute('COMMIT');
      return result;
    } catch (error) {
      await this.execute('ROLLBACK');
      throw error;
    }
  }

  async close(): Promise<void> {
    if (this.db !== null) {
      await this.sqlite.close(this.db);
      this.db = null;
    }
    await this.vfs?.close?.();
    this.vfs = null;
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
  }
}

const rowToObject = <T>(columns: string[], row: SqlValue[]) => {
  const record: SqlRow = {};
  columns.forEach((column, index) => {
    record[column] = row[index] ?? null;
  });
  return record as unknown as T;
};
