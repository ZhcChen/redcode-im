import { MemorySqlAdapter } from './memory-sql-adapter';
import type { SqlAdapter, SqlRow, SqlValue } from './sql-adapter';

interface PersistedState {
  chatRows: Array<[string, unknown]>;
  contactRows: Array<[string, unknown]>;
  messages: Array<[string, unknown]>;
  searchRows: Array<[string, unknown]>;
}

const STORE_NAME = 'state';
const STATE_KEY = 'cache';

export class IndexedDbSqlAdapter implements SqlAdapter {
  private readonly memory = new MemorySqlAdapter();
  private readonly ready: Promise<IDBDatabase>;
  private writeChain: Promise<void> = Promise.resolve();
  private transactionDepth = 0;
  private transactionDirty = false;

  private constructor(private readonly databaseName: string) {
    this.ready = this.open();
  }

  static async create(databaseName = 'redcode-h5-cache'): Promise<IndexedDbSqlAdapter> {
    const adapter = new IndexedDbSqlAdapter(databaseName);
    await adapter.restore();
    return adapter;
  }

  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    await this.memory.execute(sql, params);
    if (this.transactionDepth > 0) {
      this.transactionDirty = true;
      return;
    }
    await this.persist();
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    return this.memory.query<T>(sql, params);
  }

  async transaction<T>(work: () => Promise<T>): Promise<T> {
    const isOuterTransaction = this.transactionDepth === 0;
    const previousDirty = this.transactionDirty;
    this.transactionDepth += 1;
    let succeeded = false;

    try {
      const result = await this.memory.transaction(work);
      succeeded = true;
      return result;
    } catch (error) {
      this.transactionDirty = isOuterTransaction ? false : previousDirty;
      throw error;
    } finally {
      this.transactionDepth -= 1;
      if (isOuterTransaction && succeeded) {
        const shouldPersist = this.transactionDirty;
        this.transactionDirty = false;
        if (shouldPersist) {
          await this.persist();
        }
      }
    }
  }

  async close(): Promise<void> {
    const db = await this.ready;
    db.close();
  }

  private async open(): Promise<IDBDatabase> {
    if (typeof indexedDB === 'undefined') {
      throw new Error('IndexedDB is not available');
    }

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.databaseName, 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore(STORE_NAME);
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error ?? new Error('IndexedDB open failed'));
    });
  }

  private async restore() {
    const state = await this.readState();
    if (!state) return;
    restoreMap(this.memory.chatRows, state.chatRows);
    restoreMap(this.memory.contactRows, state.contactRows);
    restoreMap(this.memory.messages, state.messages);
    restoreMap(this.memory.searchRows, state.searchRows);
  }

  private async persist() {
    this.writeChain = this.writeChain.then(() => this.writeState(this.snapshot()));
    await this.writeChain;
  }

  private snapshot(): PersistedState {
    return {
      chatRows: [...this.memory.chatRows.entries()],
      contactRows: [...this.memory.contactRows.entries()],
      messages: [...this.memory.messages.entries()],
      searchRows: [...this.memory.searchRows.entries()],
    };
  }

  private async readState(): Promise<PersistedState | null> {
    const db = await this.ready;
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(STORE_NAME, 'readonly');
      const request = transaction.objectStore(STORE_NAME).get(STATE_KEY);
      request.onsuccess = () => resolve((request.result as PersistedState | undefined) ?? null);
      request.onerror = () => reject(request.error ?? new Error('IndexedDB read failed'));
    });
  }

  private async writeState(state: PersistedState): Promise<void> {
    const db = await this.ready;
    await new Promise<void>((resolve, reject) => {
      const transaction = db.transaction(STORE_NAME, 'readwrite');
      const request = transaction.objectStore(STORE_NAME).put(state, STATE_KEY);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error ?? new Error('IndexedDB write failed'));
    });
  }
}

const restoreMap = <T>(target: Map<string, T>, entries: Array<[string, unknown]> | undefined) => {
  target.clear();
  for (const [key, value] of entries ?? []) {
    target.set(key, value as T);
  }
};
