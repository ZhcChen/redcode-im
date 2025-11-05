const INDEX_KEY = 'avatar_cache_index_v1';
const DATA_PREFIX = 'avatar_cache_data_';

interface AvatarRecord {
  key: string;
  storageKey: string;
  contentType?: string;
}

type AvatarIndex = Record<string, AvatarRecord>;

const memoryBlobs: Record<string, string> = {};

function readIndex(): AvatarIndex {
  if (typeof window === 'undefined' || !window.localStorage) {
    return {};
  }
  try {
    const raw = window.localStorage.getItem(INDEX_KEY);
    if (!raw) {
      return {};
    }
    return JSON.parse(raw) as AvatarIndex;
  } catch (error) {
    console.warn('[AvatarCache] 读取索引失败，已重置:', error);
    return {};
  }
}

function writeIndex(index: AvatarIndex) {
  if (typeof window === 'undefined' || !window.localStorage) {
    return;
  }
  try {
    window.localStorage.setItem(INDEX_KEY, JSON.stringify(index));
  } catch (error) {
    console.warn('[AvatarCache] 写入索引失败:', error);
  }
}

function toBase64(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.length; i += 1) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function createBlobUrl(record: AvatarRecord, data: string): string {
  const bytes = fromBase64(data);
  const blob = new Blob([bytes], { type: record.contentType || 'application/octet-stream' });
  const url = URL.createObjectURL(blob);
  memoryBlobs[record.storageKey] = url;
  return url;
}

export interface SaveAvatarOptions {
  userId: string;
  objectKey: string;
  data: Uint8Array;
  filename?: string;
  contentType?: string;
}

export interface AvatarCacheResult {
  path: string;
  webPath: string;
}

export const AvatarCache = {
  async clear(userId: string) {
    const index = readIndex();
    const record = index[userId];
    if (!record) return;
    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.removeItem(record.storageKey);
    }
    const url = memoryBlobs[record.storageKey];
    if (url) {
      URL.revokeObjectURL(url);
      delete memoryBlobs[record.storageKey];
    }
    delete index[userId];
    writeIndex(index);
  },

  async resolve(userId: string, objectKey: string): Promise<AvatarCacheResult | null> {
    const index = readIndex();
    const record = index[userId];
    if (!record || record.key !== objectKey) {
      return null;
    }
    if (typeof window === 'undefined' || !window.localStorage) {
      return null;
    }
    const stored = window.localStorage.getItem(record.storageKey);
    if (!stored) {
      delete index[userId];
      writeIndex(index);
      return null;
    }
    if (memoryBlobs[record.storageKey]) {
      return { path: record.storageKey, webPath: memoryBlobs[record.storageKey] };
    }
    const url = createBlobUrl(record, stored);
    return { path: record.storageKey, webPath: url };
  },

  async save(options: SaveAvatarOptions): Promise<AvatarCacheResult> {
    const { userId, objectKey, data, contentType } = options;
    if (typeof window === 'undefined' || !window.localStorage) {
      const blobUrl = memoryBlobs[objectKey];
      if (blobUrl) {
        URL.revokeObjectURL(blobUrl);
      }
      const blob = new Blob([data], { type: contentType || 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      memoryBlobs[objectKey] = url;
      return { path: objectKey, webPath: url };
    }

    const index = readIndex();
    const storageKey = `${DATA_PREFIX}${userId}`;
    const previous = index[userId];
    if (previous && previous.storageKey !== storageKey) {
      window.localStorage.removeItem(previous.storageKey);
      const oldUrl = memoryBlobs[previous.storageKey];
      if (oldUrl) {
        URL.revokeObjectURL(oldUrl);
        delete memoryBlobs[previous.storageKey];
      }
    }

    window.localStorage.setItem(storageKey, toBase64(data));
    index[userId] = {
      key: objectKey,
      storageKey,
      contentType
    };
    writeIndex(index);

    if (memoryBlobs[storageKey]) {
      URL.revokeObjectURL(memoryBlobs[storageKey]);
      delete memoryBlobs[storageKey];
    }

    const url = createBlobUrl(index[userId], window.localStorage.getItem(storageKey) as string);
    return { path: storageKey, webPath: url };
  }
};
