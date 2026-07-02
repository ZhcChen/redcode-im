/// <reference types="vite/client" />

declare module 'wa-sqlite/dist/wa-sqlite-async.mjs' {
  const factory: () => Promise<unknown>;
  export default factory;
}

declare module 'wa-sqlite/src/examples/IDBBatchAtomicVFS.js' {
  export class IDBBatchAtomicVFS {
    constructor(
      idbDatabaseName?: string,
      options?: {
        durability?: 'default' | 'strict' | 'relaxed';
        purge?: 'deferred' | 'manual';
        purgeAtLeast?: number;
      },
    );
    readonly name: string;
    close(): Promise<void>;
  }
}
