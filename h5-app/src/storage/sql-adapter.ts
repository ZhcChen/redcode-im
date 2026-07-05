export type SqlValue = string | number | Uint8Array | null;
export type SqlRow = Record<string, SqlValue | undefined>;
export type SqlTransactionWork<T> = (adapter: SqlAdapter) => Promise<T>;

export interface SqlAdapter {
  execute(sql: string, params?: readonly SqlValue[]): Promise<void>;
  query<T = SqlRow>(sql: string, params?: readonly SqlValue[]): Promise<T[]>;
  transaction<T>(work: SqlTransactionWork<T>): Promise<T>;
  close(): Promise<void>;
}

export class UnsupportedSqlAdapter implements SqlAdapter {
  constructor(private readonly reason: string) {}

  async execute(): Promise<void> {
    throw new Error(this.reason);
  }

  async query<T = SqlRow>(): Promise<T[]> {
    throw new Error(this.reason);
  }

  async transaction<T>(): Promise<T> {
    throw new Error(this.reason);
  }

  async close(): Promise<void> {
    return Promise.resolve();
  }
}
