import { webcrypto } from 'node:crypto';

import { describe, expect, it } from 'vitest';

import {
  E2eeIdentityTrustManager,
  E2eeIdentityNotTrustedError,
  type E2eeIdentityTrustRecord,
  type E2eeIdentityTrustStore,
  type E2eeRootIdentity,
} from '@/e2ee/identity-trust';

const clock = new Date('2026-08-04T12:00:00.000Z');

describe('E2eeIdentityTrustManager', () => {
  it('trusts first use and blocks changed identities until explicit retrust', async () => {
    const store = new MemoryTrustStore();
    const manager = new E2eeIdentityTrustManager(store, () => clock);

    await expect(manager.observe('alice', identity('bob', 1))).resolves.toBe('first-use-trusted');
    await expect(manager.observe('alice', identity('bob', 1))).resolves.toBe('trusted');
    await expect(manager.observe('alice', identity('bob', 2))).resolves.toBe('identity-changed');

    const changed = await manager.record('alice', 'bob');
    expect(changed?.trusted.fingerprint[0]).toBe(1);
    expect(changed?.pending?.fingerprint[0]).toBe(2);
    await expect(manager.requireTrusted('alice', 'bob')).rejects
      .toBeInstanceOf(E2eeIdentityNotTrustedError);
    expect((await manager.retrust('alice', 'bob')).trusted.fingerprint[0]).toBe(2);
    await expect(manager.requireTrusted('alice', 'bob')).resolves.toBeDefined();
  });

  it('keeps registries account scoped and serializes deterministically', async () => {
    const store = new MemoryTrustStore();
    const manager = new E2eeIdentityTrustManager(store, () => clock);
    await manager.observe('alice', identity('bob', 1));

    expect(await manager.record('carol', 'bob')).toBeUndefined();
    const encoded = E2eeIdentityTrustManager.encodeRegistry(await store.readRecords('alice'));
    expect(E2eeIdentityTrustManager.decodeRegistry(encoded).bob?.trusted.fingerprint[0]).toBe(1);
  });

  it('matches the Flutter symmetric security-code vector', async () => {
    const first = await E2eeIdentityTrustManager.securityCode(
      identity('alice', 1),
      identity('bob', 2),
      webcrypto as unknown as Crypto,
    );
    const reversed = await E2eeIdentityTrustManager.securityCode(
      identity('bob', 2),
      identity('alice', 1),
      webcrypto as unknown as Crypto,
    );

    expect(reversed).toBe(first);
    expect(first).toBe(
      'C05E 7601 822E A6B9 CEC2 FF90 D63C 6F35 '
      + '47D9 29F4 DC88 678A 9605 AF94 4A1A EEF4',
    );
  });

  it('uses locale-independent account ordering', async () => {
    const first = await E2eeIdentityTrustManager.securityCode(
      identity('Z-user', 3),
      identity('_user', 4),
      webcrypto as unknown as Crypto,
    );
    const reversed = await E2eeIdentityTrustManager.securityCode(
      identity('_user', 4),
      identity('Z-user', 3),
      webcrypto as unknown as Crypto,
    );

    expect(reversed).toBe(first);
  });
});

const identity = (userId: string, marker: number): E2eeRootIdentity => ({
  userId,
  publicKey: new Uint8Array(32).fill(marker + 10),
  fingerprint: new Uint8Array(32).fill(marker),
  protocolVersion: 1,
});

class MemoryTrustStore implements E2eeIdentityTrustStore {
  private readonly values = new Map<string, Record<string, E2eeIdentityTrustRecord>>();

  async readRecords(accountId: string) {
    return { ...(this.values.get(accountId) ?? {}) };
  }

  async writeRecords(accountId: string, records: Record<string, E2eeIdentityTrustRecord>) {
    this.values.set(accountId, { ...records });
  }

  async deleteRecords(accountId: string) {
    this.values.delete(accountId);
  }
}
