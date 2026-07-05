import { beforeEach, describe, expect, it, vi } from 'vitest';

import { BlobCache } from '@/storage/blob-cache';

const namespace = 'blob-cache-test';

describe('BlobCache', () => {
  let now = 1_000;

  beforeEach(() => {
    now = 1_000;
    vi.stubGlobal('caches', undefined);
    vi.stubGlobal('fetch', vi.fn());
    Object.defineProperty(URL, 'createObjectURL', {
      configurable: true,
      value: vi.fn(() => 'blob:test-url'),
    });
    Object.defineProperty(URL, 'revokeObjectURL', {
      configurable: true,
      value: vi.fn(),
    });
  });

  it('saves and resolves cached blobs by object key', async () => {
    const cache = new BlobCache({ namespace, now: () => now });

    const saved = await cache.save({
      cacheKey: 'avatar:u1',
      objectKey: 'avatars/u1.png',
      blob: new Blob(['avatar'], { type: 'image/png' }),
    });
    const resolved = await cache.resolve('avatar:u1', 'avatars/u1.png');

    expect(saved).toMatchObject({
      cacheKey: 'avatar:u1',
      objectKey: 'avatars/u1.png',
      mimeType: 'image/png',
      size: 6,
    });
    expect(resolved).toMatchObject({
      cacheKey: 'avatar:u1',
      objectKey: 'avatars/u1.png',
      mimeType: 'image/png',
      size: 6,
    });
  });

  it('removes stale metadata when object key changes', async () => {
    const cache = new BlobCache({ namespace, now: () => now });
    await cache.save({
      cacheKey: 'avatar:u1',
      objectKey: 'avatars/old.png',
      blob: new Blob(['old']),
    });

    const resolved = await cache.resolve('avatar:u1', 'avatars/new.png');

    expect(resolved).toBeNull();
    expect(window.localStorage.getItem(`${namespace}:meta:avatar:u1`)).toBeNull();
  });

  it('expires cached blobs by ttl', async () => {
    const cache = new BlobCache({ namespace, ttlMs: 100, now: () => now });
    await cache.save({
      cacheKey: 'message:file',
      objectKey: 'messages/file.png',
      blob: new Blob(['file']),
    });

    now = 1_101;

    expect(await cache.resolve('message:file', 'messages/file.png')).toBeNull();
    expect(window.localStorage.getItem(`${namespace}:meta:message:file`)).toBeNull();
  });

  it('does not write metadata when fetch fails', async () => {
    const fetchMock = vi.fn(async () => new Response('missing', { status: 404 }));
    vi.stubGlobal('fetch', fetchMock);
    const cache = new BlobCache({ namespace, now: () => now });

    const resolved = await cache.fetchAndCache({
      cacheKey: 'message:missing',
      objectKey: 'messages/missing.png',
      url: 'https://cdn.example/missing.png',
    });

    expect(resolved).toBeNull();
    expect(window.localStorage.getItem(`${namespace}:meta:message:missing`)).toBeNull();
  });

  it('clears all entries for its namespace only', async () => {
    const cache = new BlobCache({ namespace, now: () => now });
    await cache.save({
      cacheKey: 'avatar:u1',
      objectKey: 'avatars/u1.png',
      blob: new Blob(['avatar']),
    });
    window.localStorage.setItem('other:meta:avatar:u2', 'keep');

    await cache.clearAll();

    expect(window.localStorage.getItem(`${namespace}:meta:avatar:u1`)).toBeNull();
    expect(window.localStorage.getItem('other:meta:avatar:u2')).toBe('keep');
  });

  it('cleans up expired entries and reports removed bytes', async () => {
    const cache = new BlobCache({ namespace, ttlMs: 100, now: () => now });
    await cache.save({
      cacheKey: 'old',
      objectKey: 'old.png',
      blob: new Blob(['old']),
    });
    now = 1_101;

    const result = await cache.cleanup();

    expect(result).toMatchObject({
      removed: 1,
      entriesBefore: 1,
      entriesAfter: 0,
      bytesBefore: 3,
      bytesAfter: 0,
    });
  });

  it('keeps cache under max entry count using oldest-first cleanup', async () => {
    const cache = new BlobCache({ namespace, maxEntries: 2, now: () => now });
    await cache.save({ cacheKey: 'a', objectKey: 'a.png', blob: new Blob(['a']) });
    now += 1;
    await cache.save({ cacheKey: 'b', objectKey: 'b.png', blob: new Blob(['b']) });
    now += 1;
    await cache.save({ cacheKey: 'c', objectKey: 'c.png', blob: new Blob(['c']) });

    expect(await cache.resolve('a', 'a.png')).toBeNull();
    expect(await cache.resolve('b', 'b.png')).not.toBeNull();
    expect(await cache.resolve('c', 'c.png')).not.toBeNull();
  });

  it('keeps cache under max byte count using oldest-first cleanup', async () => {
    const cache = new BlobCache({ namespace, maxBytes: 5, now: () => now });
    await cache.save({ cacheKey: 'a', objectKey: 'a.png', blob: new Blob(['123']) });
    now += 1;
    await cache.save({ cacheKey: 'b', objectKey: 'b.png', blob: new Blob(['456']) });

    expect(await cache.resolve('a', 'a.png')).toBeNull();
    expect(await cache.resolve('b', 'b.png')).not.toBeNull();
  });
});
