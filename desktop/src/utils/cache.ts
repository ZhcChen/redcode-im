const CACHE_VERSION = 1;

interface CacheEnvelope<T> {
  version: number;
  updatedAt: number;
  data: T;
}

const hasStorage = typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';

const readItem = <T>(key: string): CacheEnvelope<T> | null => {
  if (!hasStorage) {
    return null;
  }

  const raw = window.localStorage.getItem(key);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as CacheEnvelope<T>;
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    if (parsed.version !== CACHE_VERSION || typeof parsed.updatedAt !== 'number') {
      return null;
    }
    return parsed;
  } catch (error) {
    console.warn('[cache] 读取失败，移除损坏的缓存:', key, error);
    try {
      window.localStorage.removeItem(key);
    } catch (removeError) {
      console.warn('[cache] 移除损坏缓存失败:', removeError);
    }
    return null;
  }
};

const writeItem = <T>(key: string, data: T) => {
  if (!hasStorage) {
    return;
  }
  const envelope: CacheEnvelope<T> = {
    version: CACHE_VERSION,
    updatedAt: Date.now(),
    data,
  };
  try {
    window.localStorage.setItem(key, JSON.stringify(envelope));
  } catch (error) {
    console.warn('[cache] 写入失败，尝试移除旧缓存:', key, error);
    try {
      window.localStorage.removeItem(key);
    } catch (removeError) {
      console.warn('[cache] 移除旧缓存失败:', removeError);
    }
  }
};

const deleteItem = (key: string) => {
  if (!hasStorage) {
    return;
  }
  try {
    window.localStorage.removeItem(key);
  } catch (error) {
    console.warn('[cache] 删除缓存失败:', key, error);
  }
};

export const CACHE_KEYS = {
  chatList: 'cache.chat_list',
  contacts: 'cache.contacts',
  friendRequests: 'cache.friend_requests',
  messages: (roomId: string) => `cache.messages.${roomId}`,
};

export const loadCache = <T>(key: string): CacheEnvelope<T> | null => readItem<T>(key);

export const saveCache = <T>(key: string, data: T) => writeItem<T>(key, data);

export const removeCache = (key: string) => deleteItem(key);

export interface CacheSnapshot<T> {
  data: T;
  updatedAt: number;
}
