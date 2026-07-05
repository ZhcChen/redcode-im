export interface CachedBlobEntry {
  cacheKey: string;
  objectKey: string;
  objectUrl: string;
  mimeType: string;
  size: number;
  cachedAt: number;
}

interface BlobCacheMetadata {
  objectKey: string;
  mimeType: string;
  size: number;
  cachedAt: number;
}

export interface BlobCachePolicy {
  ttlMs: number;
  maxEntries: number;
  maxBytes: number;
}

export interface BlobCacheCleanupResult {
  removed: number;
  entriesBefore: number;
  entriesAfter: number;
  bytesBefore: number;
  bytesAfter: number;
}

interface BlobCacheOptions {
  namespace?: string;
  ttlMs?: number;
  maxEntries?: number;
  maxBytes?: number;
  now?: () => number;
}

const DEFAULT_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_MAX_ENTRIES = 500;
const DEFAULT_MAX_BYTES = 100 * 1024 * 1024;
const memoryBlobs = new Map<string, Blob>();

export const DEFAULT_BLOB_CACHE_POLICY: BlobCachePolicy = {
  ttlMs: DEFAULT_TTL_MS,
  maxEntries: DEFAULT_MAX_ENTRIES,
  maxBytes: DEFAULT_MAX_BYTES,
};

export class BlobCache {
  private readonly namespace: string;
  private readonly policy: BlobCachePolicy;
  private readonly now: () => number;

  constructor(options: BlobCacheOptions = {}) {
    this.namespace = options.namespace ?? 'redcode-h5-blob-cache';
    this.policy = {
      ttlMs: options.ttlMs ?? DEFAULT_TTL_MS,
      maxEntries: options.maxEntries ?? DEFAULT_MAX_ENTRIES,
      maxBytes: options.maxBytes ?? DEFAULT_MAX_BYTES,
    };
    this.now = options.now ?? (() => Date.now());
  }

  async resolve(cacheKey: string, objectKey?: string | null): Promise<CachedBlobEntry | null> {
    if (!cacheKey) return null;
    const metadata = this.readMetadata(cacheKey);
    if (!metadata) return null;
    if (objectKey && metadata.objectKey !== objectKey) {
      await this.remove(cacheKey);
      return null;
    }
    if (this.isExpired(metadata)) {
      await this.remove(cacheKey);
      return null;
    }

    const blob = await this.readBlob(cacheKey);
    if (!blob) {
      this.removeMetadata(cacheKey);
      return null;
    }

    return {
      cacheKey,
      objectKey: metadata.objectKey,
      objectUrl: createObjectUrl(blob, cacheKey),
      mimeType: metadata.mimeType,
      size: metadata.size,
      cachedAt: metadata.cachedAt,
    };
  }

  async save(params: { cacheKey: string; objectKey: string; blob: Blob }): Promise<CachedBlobEntry> {
    const cachedAt = this.now();
    await this.writeBlob(params.cacheKey, params.blob);
    const metadata: BlobCacheMetadata = {
      objectKey: params.objectKey,
      mimeType: params.blob.type || 'application/octet-stream',
      size: params.blob.size,
      cachedAt,
    };
    this.writeMetadata(params.cacheKey, metadata);
    await this.cleanup();
    return {
      cacheKey: params.cacheKey,
      objectKey: params.objectKey,
      objectUrl: createObjectUrl(params.blob, params.cacheKey),
      mimeType: metadata.mimeType,
      size: metadata.size,
      cachedAt,
    };
  }

  async fetchAndCache(params: {
    cacheKey: string;
    objectKey: string;
    url: string;
    init?: RequestInit;
  }): Promise<CachedBlobEntry | null> {
    const cached = await this.resolve(params.cacheKey, params.objectKey);
    if (cached) return cached;

    try {
      const response = await fetch(params.url, params.init);
      if (!response.ok) return null;
      const blob = await response.blob();
      return await this.save({ cacheKey: params.cacheKey, objectKey: params.objectKey, blob });
    } catch {
      await this.remove(params.cacheKey);
      return null;
    }
  }

  async cleanup(): Promise<BlobCacheCleanupResult> {
    const entries = this.readAllMetadata();
    const bytesBefore = sumMetadataBytes(entries);
    const keysToRemove = new Set<string>();
    entries
      .filter((entry) => this.isExpired(entry.metadata))
      .forEach((entry) => keysToRemove.add(entry.cacheKey));

    const survivors = entries
      .filter((entry) => !keysToRemove.has(entry.cacheKey))
      .sort((a, b) => a.metadata.cachedAt - b.metadata.cachedAt);
    let survivorBytes = sumMetadataBytes(survivors);

    while (survivors.length > this.policy.maxEntries || survivorBytes > this.policy.maxBytes) {
      const oldest = survivors.shift();
      if (!oldest) break;
      keysToRemove.add(oldest.cacheKey);
      survivorBytes -= oldest.metadata.size;
    }

    for (const key of keysToRemove) {
      await this.remove(key);
    }

    const remaining = this.readAllMetadata();
    return {
      removed: keysToRemove.size,
      entriesBefore: entries.length,
      entriesAfter: remaining.length,
      bytesBefore,
      bytesAfter: sumMetadataBytes(remaining),
    };
  }

  getPolicy(): BlobCachePolicy {
    return { ...this.policy };
  }

  async remove(cacheKey: string): Promise<void> {
    this.removeMetadata(cacheKey);
    memoryBlobs.delete(this.storageKey(cacheKey));
    if (!hasCacheApi()) return;
    const cache = await caches.open(this.namespace);
    await cache.delete(this.requestUrl(cacheKey));
  }

  async clearAll(): Promise<void> {
    Array.from({ length: window.localStorage.length }, (_, index) => window.localStorage.key(index))
      .filter((key): key is string => Boolean(key?.startsWith(`${this.namespace}:meta:`)))
      .forEach((key) => window.localStorage.removeItem(key));
    for (const key of memoryBlobs.keys()) {
      if (key.startsWith(`${this.namespace}:blob:`)) {
        memoryBlobs.delete(key);
      }
    }
    if (hasCacheApi()) {
      await caches.delete(this.namespace);
    }
  }

  revoke(entry: Pick<CachedBlobEntry, 'objectUrl'> | null | undefined): void {
    if (!entry?.objectUrl || !entry.objectUrl.startsWith('blob:')) return;
    URL.revokeObjectURL?.(entry.objectUrl);
  }

  private async readBlob(cacheKey: string): Promise<Blob | null> {
    const key = this.storageKey(cacheKey);
    const memory = memoryBlobs.get(key);
    if (memory) return memory;
    if (!hasCacheApi()) return null;
    const cache = await caches.open(this.namespace);
    const response = await cache.match(this.requestUrl(cacheKey));
    return response ? response.blob() : null;
  }

  private async writeBlob(cacheKey: string, blob: Blob): Promise<void> {
    const key = this.storageKey(cacheKey);
    memoryBlobs.set(key, blob);
    if (!hasCacheApi()) return;
    const cache = await caches.open(this.namespace);
    await cache.put(this.requestUrl(cacheKey), new Response(blob));
  }

  private readMetadata(cacheKey: string): BlobCacheMetadata | null {
    try {
      const raw = window.localStorage.getItem(this.metadataKey(cacheKey));
      if (!raw) return null;
      const parsed = JSON.parse(raw) as Partial<BlobCacheMetadata>;
      if (!parsed.objectKey || typeof parsed.cachedAt !== 'number') return null;
      return {
        objectKey: parsed.objectKey,
        mimeType: parsed.mimeType || 'application/octet-stream',
        size: Number(parsed.size ?? 0),
        cachedAt: parsed.cachedAt,
      };
    } catch {
      return null;
    }
  }

  private writeMetadata(cacheKey: string, metadata: BlobCacheMetadata): void {
    window.localStorage.setItem(this.metadataKey(cacheKey), JSON.stringify(metadata));
  }

  private readAllMetadata() {
    return Array.from({ length: window.localStorage.length }, (_, index) => window.localStorage.key(index))
      .filter((key): key is string => Boolean(key?.startsWith(`${this.namespace}:meta:`)))
      .map((key) => {
        const cacheKey = key.slice(`${this.namespace}:meta:`.length);
        return { cacheKey, metadata: this.readMetadata(cacheKey) };
      })
      .filter((entry): entry is { cacheKey: string; metadata: BlobCacheMetadata } => Boolean(entry.metadata));
  }

  private isExpired(metadata: Pick<BlobCacheMetadata, 'cachedAt'>) {
    return this.now() - metadata.cachedAt > this.policy.ttlMs;
  }

  private removeMetadata(cacheKey: string): void {
    window.localStorage.removeItem(this.metadataKey(cacheKey));
  }

  private metadataKey(cacheKey: string) {
    return `${this.namespace}:meta:${cacheKey}`;
  }

  private storageKey(cacheKey: string) {
    return `${this.namespace}:blob:${cacheKey}`;
  }

  private requestUrl(cacheKey: string) {
    return `/__redcode_h5_blob_cache__/${encodeURIComponent(this.namespace)}/${encodeURIComponent(cacheKey)}`;
  }
}

const hasCacheApi = () => typeof caches !== 'undefined' && typeof caches.open === 'function';

const sumMetadataBytes = (entries: Array<{ metadata: Pick<BlobCacheMetadata, 'size'> }>) =>
  entries.reduce((sum, entry) => sum + Number(entry.metadata.size ?? 0), 0);

const createObjectUrl = (blob: Blob, cacheKey: string) => {
  if (typeof URL.createObjectURL === 'function') {
    return URL.createObjectURL(blob);
  }
  return `blob:redcode-h5/${encodeURIComponent(cacheKey)}`;
};
