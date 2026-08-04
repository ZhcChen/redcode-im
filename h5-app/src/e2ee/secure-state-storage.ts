import { validateE2eeProtocolState } from '@/e2ee/core-bridge';

const DATABASE_NAME = 'redcode-h5-e2ee-state';
const DATABASE_VERSION = 1;
const KEY_STORE = 'wrapping-keys';
const STATE_STORE = 'encrypted-states';
const STATE_VERSION = 1;
const NONCE_BYTES = 12;
const AAD_PREFIX = 'redcode-im/e2ee-state/v1\0';

interface StoredEncryptedState {
  version: number;
  nonce: number[];
  ciphertext: number[];
}

export class E2eeStorageUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeStorageUnavailableError';
  }
}

export class E2eeStateCorruptedError extends Error {
  constructor(message = 'E2EE 协议状态已损坏或无法解密') {
    super(message);
    this.name = 'E2eeStateCorruptedError';
  }
}

export interface E2eeSecureStateStorageOptions {
  databaseName?: string;
  indexedDb?: IDBFactory | null;
  crypto?: Crypto | null;
  validateProtocolState?: (state: Uint8Array) => Promise<boolean>;
}

export class E2eeSecureStateStorage {
  private readonly databaseName: string;
  private readonly indexedDb?: IDBFactory;
  private readonly cryptoProvider?: Crypto;
  private readonly validateProtocolState: (state: Uint8Array) => Promise<boolean>;

  constructor(options: E2eeSecureStateStorageOptions = {}) {
    this.databaseName = options.databaseName ?? DATABASE_NAME;
    this.indexedDb = options.indexedDb === undefined
      ? globalThis.indexedDB
      : options.indexedDb ?? undefined;
    this.cryptoProvider = options.crypto === undefined
      ? globalThis.crypto
      : options.crypto ?? undefined;
    this.validateProtocolState = options.validateProtocolState ?? validateE2eeProtocolState;
  }

  async write(accountId: string, state: Uint8Array): Promise<void> {
    if (!await this.validateProtocolState(state)) {
      throw new E2eeStateCorruptedError('拒绝保存无效的 E2EE 协议状态');
    }
    const namespace = this.accountNamespace(accountId);
    const db = await this.open();
    try {
      let wrappingKey = await readRecord<CryptoKey>(db, KEY_STORE, namespace);
      if (!wrappingKey) {
        wrappingKey = await this.subtle().generateKey(
          { name: 'AES-GCM', length: 256 },
          false,
          ['encrypt', 'decrypt'],
        ) as CryptoKey;
        await writeRecord(db, KEY_STORE, namespace, wrappingKey);
      }

      const nonce = this.randomBytes(NONCE_BYTES);
      const ciphertext = await this.subtle().encrypt(
        {
          name: 'AES-GCM',
          iv: toArrayBuffer(nonce),
          additionalData: toArrayBuffer(this.associatedData(accountId)),
          tagLength: 128,
        },
        wrappingKey,
        toArrayBuffer(state),
      );
      await writeRecord<StoredEncryptedState>(db, STATE_STORE, namespace, {
        version: STATE_VERSION,
        nonce: Array.from(nonce),
        ciphertext: Array.from(new Uint8Array(ciphertext)),
      });
    } finally {
      db.close();
    }
  }

  async read(accountId: string): Promise<Uint8Array | null> {
    const namespace = this.accountNamespace(accountId);
    const db = await this.open();
    try {
      const encrypted = await readRecord<StoredEncryptedState>(db, STATE_STORE, namespace);
      if (!encrypted) return null;
      const wrappingKey = await readRecord<CryptoKey>(db, KEY_STORE, namespace);
      if (!wrappingKey || encrypted.version !== STATE_VERSION) {
        throw new E2eeStateCorruptedError();
      }
      try {
        const plaintext = await this.subtle().decrypt(
          {
            name: 'AES-GCM',
            iv: toArrayBuffer(new Uint8Array(encrypted.nonce)),
            additionalData: toArrayBuffer(this.associatedData(accountId)),
            tagLength: 128,
          },
          wrappingKey,
          toArrayBuffer(new Uint8Array(encrypted.ciphertext)),
        );
        const state = new Uint8Array(plaintext);
        if (!await this.validateProtocolState(state)) {
          throw new E2eeStateCorruptedError();
        }
        return state;
      } catch (error) {
        if (error instanceof E2eeStateCorruptedError) throw error;
        throw new E2eeStateCorruptedError();
      }
    } finally {
      db.close();
    }
  }

  async delete(accountId: string): Promise<void> {
    if (!this.indexedDb) return;
    const namespace = this.accountNamespace(accountId);
    const db = await this.open();
    try {
      await Promise.all([
        deleteRecord(db, KEY_STORE, namespace),
        deleteRecord(db, STATE_STORE, namespace),
      ]);
    } finally {
      db.close();
    }
  }

  private subtle(): SubtleCrypto {
    const subtle = this.cryptoProvider?.subtle;
    if (!subtle) {
      throw new E2eeStorageUnavailableError('当前浏览器不支持 WebCrypto，无法启用 E2EE');
    }
    return subtle;
  }

  private randomBytes(length: number): Uint8Array {
    if (!this.cryptoProvider?.getRandomValues) {
      throw new E2eeStorageUnavailableError('当前浏览器缺少安全随机数，无法启用 E2EE');
    }
    return this.cryptoProvider.getRandomValues(new Uint8Array(length));
  }

  private accountNamespace(accountId: string): string {
    const normalized = accountId.trim();
    if (!normalized) throw new E2eeStateCorruptedError('E2EE 账号标识不能为空');
    return `account:${normalized}`;
  }

  private associatedData(accountId: string): Uint8Array {
    return new TextEncoder().encode(`${AAD_PREFIX}${accountId.trim()}`);
  }

  private async open(): Promise<IDBDatabase> {
    if (!this.indexedDb) {
      throw new E2eeStorageUnavailableError('当前浏览器不支持 IndexedDB，无法启用 E2EE');
    }
    return new Promise((resolve, reject) => {
      const request = this.indexedDb!.open(this.databaseName, DATABASE_VERSION);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(KEY_STORE)) db.createObjectStore(KEY_STORE);
        if (!db.objectStoreNames.contains(STATE_STORE)) db.createObjectStore(STATE_STORE);
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(new E2eeStorageUnavailableError('E2EE IndexedDB 打开失败'));
    });
  }
}

export const e2eeSecureStateStorage = new E2eeSecureStateStorage();

function readRecord<T>(db: IDBDatabase, storeName: string, key: string): Promise<T | null> {
  return new Promise((resolve, reject) => {
    const request = db.transaction(storeName, 'readonly').objectStore(storeName).get(key);
    request.onsuccess = () => resolve((request.result as T | undefined) ?? null);
    request.onerror = () => reject(request.error ?? new Error('IndexedDB read failed'));
  });
}

function writeRecord<T>(db: IDBDatabase, storeName: string, key: string, value: T): Promise<void> {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    transaction.objectStore(storeName).put(value, key);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error('IndexedDB write failed'));
    transaction.onabort = () => reject(transaction.error ?? new Error('IndexedDB write aborted'));
  });
}

function deleteRecord(db: IDBDatabase, storeName: string, key: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(storeName, 'readwrite');
    transaction.objectStore(storeName).delete(key);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error('IndexedDB delete failed'));
    transaction.onabort = () => reject(transaction.error ?? new Error('IndexedDB delete aborted'));
  });
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}
