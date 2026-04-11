import { invoke } from '@tauri-apps/api/core';

const CACHE_VERSION = 1;

interface CacheEnvelope<T> {
  version: number;
  updatedAt: number;
  data: T;
}

const isBrowser = typeof window !== 'undefined';
const hasLocalStorage = isBrowser && typeof window.localStorage !== 'undefined';
const isTauriRuntime = isBrowser && typeof (window as any).__TAURI__ !== 'undefined';

const readLocalStorage = <T>(key: string): CacheEnvelope<T> | null => {
  if (!hasLocalStorage) {
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
    try {
      window.localStorage.removeItem(key);
    } catch (removeError) {
    }
    return null;
  }
};

const writeLocalStorage = <T>(key: string, data: T) => {
  if (!hasLocalStorage) {
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
    try {
      window.localStorage.removeItem(key);
    } catch (removeError) {
    }
  }
};

const deleteLocalStorage = (key: string) => {
  if (!hasLocalStorage) {
    return;
  }
  try {
    window.localStorage.removeItem(key);
  } catch (error) {
  }
};

export const CACHE_KEYS = {
  chatList: 'cache.chat_list',
  contacts: 'cache.contacts',
  friendRequests: 'cache.friend_requests',
  generalSettings: 'cache.general_settings',
  uploadPolicy: 'cache.upload_policy',
  messages: (roomId: string) => `cache.messages.${roomId}`,
};

export const loadCache = async <T>(key: string): Promise<CacheSnapshot<T> | null> => {
  if (isTauriRuntime) {
    try {
      const result = await invoke<{ data: T; updatedAt: number } | null>('cache_load_value', { key });
      return result ? { data: result.data, updatedAt: result.updatedAt } : null;
    } catch (error) {
    }
  }

  const fallback = readLocalStorage<T>(key);
  return fallback ? { data: fallback.data, updatedAt: fallback.updatedAt } : null;
};

export const saveCache = async <T>(key: string, data: T) => {
  if (isTauriRuntime) {
    try {
      await invoke('cache_save_value', { key, payload: data });
      return;
    } catch (error) {
    }
  }

  writeLocalStorage(key, data);
};

export const removeCache = async (key: string) => {
  if (isTauriRuntime) {
    try {
      await invoke('cache_clear_value', { key });
    } catch (error) {
    }
  }

  deleteLocalStorage(key);
};

export interface CacheSnapshot<T> {
  data: T;
  updatedAt: number;
}
