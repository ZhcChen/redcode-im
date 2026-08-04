import { webcrypto } from 'node:crypto';

import { IDBFactory } from 'fake-indexeddb';
import { describe, expect, it } from 'vitest';

import {
  E2eeSecureStateStorage,
  E2eeStateCorruptedError,
  E2eeStorageUnavailableError,
} from '@/e2ee/secure-state-storage';
import type { E2eeIdentityTrustRecord } from '@/e2ee/identity-trust';

const createStorage = () => new E2eeSecureStateStorage({
  databaseName: `e2ee-test-${crypto.randomUUID()}`,
  indexedDb: new IDBFactory(),
  crypto: webcrypto as unknown as Crypto,
  validateProtocolState: async () => true,
});

describe('E2eeSecureStateStorage', () => {
  it('encrypts and restores account-scoped protocol state', async () => {
    const storage = createStorage();
    const state = new Uint8Array([1, 2, 3, 4, 255]);

    await storage.write('account-a', state);

    expect(await storage.read('account-a')).toEqual(state);
    expect(await storage.read('account-b')).toBeNull();
    expect(window.localStorage.length).toBe(0);
  });

  it('destroys both ciphertext and wrapping key on account cleanup', async () => {
    const storage = createStorage();
    await storage.write('account-a', new Uint8Array([7, 8, 9]));

    await storage.delete('account-a');

    expect(await storage.read('account-a')).toBeNull();
  });

  it('encrypts identity trust records without localStorage fallback', async () => {
    const storage = createStorage();
    const record: E2eeIdentityTrustRecord = {
      trusted: {
        userId: 'account-b',
        publicKey: new Uint8Array(32).fill(7),
        fingerprint: new Uint8Array(32).fill(9),
        protocolVersion: 1,
      },
      trustedAt: '2026-08-04T00:00:00.000Z',
    };

    await storage.writeRecords('account-a', { 'account-b': record });

    expect((await storage.readRecords('account-a'))['account-b']?.trusted.fingerprint)
      .toEqual(record.trusted.fingerprint);
    expect(window.localStorage.length).toBe(0);
    await storage.deleteRecords('account-a');
    expect(await storage.readRecords('account-a')).toEqual({});
  });

  it('never persists state rejected by the shared core', async () => {
    const storage = new E2eeSecureStateStorage({
      databaseName: `e2ee-test-${crypto.randomUUID()}`,
      indexedDb: new IDBFactory(),
      crypto: webcrypto as unknown as Crypto,
      validateProtocolState: async () => false,
    });

    await expect(storage.write('account-a', new Uint8Array([1, 2, 3])))
      .rejects.toBeInstanceOf(E2eeStateCorruptedError);
    expect(await storage.read('account-a')).toBeNull();
  });

  it('fails closed when encrypted state is tampered with', async () => {
    const indexedDb = new IDBFactory();
    const databaseName = `e2ee-test-${crypto.randomUUID()}`;
    const storage = new E2eeSecureStateStorage({
      databaseName,
      indexedDb,
      crypto: webcrypto as unknown as Crypto,
      validateProtocolState: async () => true,
    });
    await storage.write('account-a', new Uint8Array([1, 2, 3]));

    const db = await openDatabase(indexedDb, databaseName);
    const namespace = 'account:account-a';
    const encrypted = await readRawState(db, namespace);
    encrypted.ciphertext[0] ^= 0xff;
    await writeRawState(db, namespace, encrypted);
    db.close();

    await expect(storage.read('account-a')).rejects.toBeInstanceOf(E2eeStateCorruptedError);
  });

  it('fails closed when identity trust ciphertext is tampered with', async () => {
    const indexedDb = new IDBFactory();
    const databaseName = `e2ee-test-${crypto.randomUUID()}`;
    const storage = new E2eeSecureStateStorage({
      databaseName,
      indexedDb,
      crypto: webcrypto as unknown as Crypto,
      validateProtocolState: async () => true,
    });
    await storage.writeRecords('account-a', {
      'account-b': {
        trusted: {
          userId: 'account-b',
          publicKey: new Uint8Array(32).fill(7),
          fingerprint: new Uint8Array(32).fill(9),
          protocolVersion: 1,
        },
        trustedAt: '2026-08-04T00:00:00.000Z',
      },
    });

    const db = await openDatabase(indexedDb, databaseName);
    const namespace = 'account:account-a:identity-trust';
    const encrypted = await readRawState(db, namespace);
    encrypted.ciphertext[0] ^= 0xff;
    await writeRawState(db, namespace, encrypted);
    db.close();

    await expect(storage.readRecords('account-a'))
      .rejects.toBeInstanceOf(E2eeStateCorruptedError);
  });

  it('keeps wrapping keys non-extractable', async () => {
    const indexedDb = new IDBFactory();
    const databaseName = `e2ee-test-${crypto.randomUUID()}`;
    const storage = new E2eeSecureStateStorage({
      databaseName,
      indexedDb,
      crypto: webcrypto as unknown as Crypto,
      validateProtocolState: async () => true,
    });
    await storage.write('account-a', new Uint8Array([1]));

    const db = await openDatabase(indexedDb, databaseName);
    const key = await readRawKey(db, 'account:account-a');
    db.close();

    expect(key.extractable).toBe(false);
    await expect(webcrypto.subtle.exportKey('raw', key)).rejects.toThrow();
  });

  it('reports missing browser capabilities instead of falling back to plaintext storage', async () => {
    const noIndexedDb = new E2eeSecureStateStorage({
      indexedDb: null,
      crypto: webcrypto as unknown as Crypto,
      validateProtocolState: async () => true,
    });
    const noWebCrypto = new E2eeSecureStateStorage({
      indexedDb: new IDBFactory(),
      crypto: null,
      validateProtocolState: async () => true,
    });

    await expect(noIndexedDb.write('account-a', new Uint8Array([1])))
      .rejects.toBeInstanceOf(E2eeStorageUnavailableError);
    await expect(noWebCrypto.write('account-a', new Uint8Array([1])))
      .rejects.toBeInstanceOf(E2eeStorageUnavailableError);
  });
});

interface RawState {
  version: number;
  nonce: number[];
  ciphertext: number[];
}

const openDatabase = (indexedDb: IDBFactory, name: string) => new Promise<IDBDatabase>((resolve, reject) => {
  const request = indexedDb.open(name, 1);
  request.onsuccess = () => resolve(request.result);
  request.onerror = () => reject(request.error);
});

const readRawState = (db: IDBDatabase, namespace: string) => new Promise<RawState>((resolve, reject) => {
  const request = db.transaction('encrypted-states', 'readonly').objectStore('encrypted-states').get(namespace);
  request.onsuccess = () => resolve(request.result as RawState);
  request.onerror = () => reject(request.error);
});

const writeRawState = (db: IDBDatabase, namespace: string, state: RawState) => new Promise<void>((resolve, reject) => {
  const transaction = db.transaction('encrypted-states', 'readwrite');
  transaction.objectStore('encrypted-states').put(state, namespace);
  transaction.oncomplete = () => resolve();
  transaction.onerror = () => reject(transaction.error);
});

const readRawKey = (db: IDBDatabase, namespace: string) => new Promise<CryptoKey>((resolve, reject) => {
  const request = db.transaction('wrapping-keys', 'readonly').objectStore('wrapping-keys').get(namespace);
  request.onsuccess = () => resolve(request.result as CryptoKey);
  request.onerror = () => reject(request.error);
});
