import SQLiteESMFactory from 'wa-sqlite/dist/wa-sqlite-async.mjs';
import * as SQLite from 'wa-sqlite';
import { OriginPrivateFileSystemVFS } from 'wa-sqlite/src/examples/OriginPrivateFileSystemVFS.js';

import type { SqlRow, SqlValue } from './sql-adapter';

interface WaSQLiteApi {
  open_v2(name: string, flags?: number, vfs?: string): Promise<number>;
  exec(db: number, sql: string, callback?: (row: SqlValue[], columns: string[]) => void): Promise<number>;
  execWithParams(db: number, sql: string, params: readonly SqlValue[]): Promise<{ columns: string[]; rows: SqlValue[][] }>;
  close(db: number): Promise<number>;
  vfs_register(vfs: { name: string }, makeDefault?: boolean): number;
}

interface WorkerRequest {
  id: number;
  type: 'open' | 'execute' | 'query' | 'close';
  databaseName?: string;
  sql?: string;
  params?: readonly SqlValue[];
}

interface WorkerResponse {
  id: number;
  ok: boolean;
  rows?: SqlRow[];
  error?: string;
}

let sqlite: WaSQLiteApi | null = null;
let db: number | null = null;
let vfs: { close?: () => Promise<void>; name: string } | null = null;
let openPromise: Promise<void> | null = null;
let queue: Promise<unknown> = Promise.resolve();

globalThis.addEventListener('message', (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  queue = queue
    .then(() => handleRequest(request))
    .then(
      (response) => post(response),
      (error) => post({
        id: request.id,
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      }),
    );
});

const handleRequest = async (request: WorkerRequest): Promise<WorkerResponse> => {
  switch (request.type) {
    case 'open':
      await openDatabase(request.databaseName || 'redcode-h5.db');
      return { id: request.id, ok: true };
    case 'execute':
      await requireOpen();
      await sqlite?.execWithParams(requireDb(), request.sql || '', request.params ?? []);
      return { id: request.id, ok: true };
    case 'query': {
      await requireOpen();
      const result = await sqlite?.execWithParams(requireDb(), request.sql || '', request.params ?? []);
      return {
        id: request.id,
        ok: true,
        rows: (result?.rows ?? []).map((row) => rowToObject(result?.columns ?? [], row)),
      };
    }
    case 'close':
      await closeDatabase();
      return { id: request.id, ok: true };
    default:
      return { id: request.id, ok: false, error: `Unsupported worker request: ${request.type}` };
  }
};

const openDatabase = async (databaseName: string) => {
  if (openPromise) return openPromise;
  openPromise = (async () => {
    if (typeof navigator?.storage?.getDirectory !== 'function') {
      throw new Error('OPFS is not available');
    }
    const module = await SQLiteESMFactory();
    sqlite = SQLite.Factory(module) as unknown as WaSQLiteApi;
    const opfsVfs = new OriginPrivateFileSystemVFS();
    vfs = opfsVfs;
    sqlite.vfs_register(opfsVfs, false);
    db = await sqlite.open_v2(databaseName, 0x06, opfsVfs.name);
    await sqlite.exec(db, `
      PRAGMA journal_mode=MEMORY;
      PRAGMA temp_store=MEMORY;
      PRAGMA cache_size=-2000;
      PRAGMA synchronous=NORMAL;
    `);
  })();
  return openPromise;
};

const requireOpen = async () => {
  if (!openPromise) throw new Error('OPFS database is not open');
  await openPromise;
};

const requireDb = () => {
  if (db === null) throw new Error('OPFS database is not open');
  return db;
};

const closeDatabase = async () => {
  if (sqlite && db !== null) {
    await sqlite.close(db);
  }
  db = null;
  await vfs?.close?.();
  vfs = null;
  sqlite = null;
  openPromise = null;
};

const rowToObject = (columns: string[], row: SqlValue[]) => {
  const record: SqlRow = {};
  columns.forEach((column, index) => {
    record[column] = row[index] ?? null;
  });
  return record;
};

const post = (response: WorkerResponse) => {
  globalThis.postMessage(response);
};
