const INDEX_KEY = 'avatar_cache_index_v3'
const DATA_PREFIX = 'avatar_cache_data_'
const DB_NAME = 'avatar-cache'
const STORE_NAME = 'avatars'

type StorageType = 'localStorage' | 'indexedDB'

interface AvatarRecord {
  key: string
  storageKey: string
  contentType?: string
  storageType?: StorageType
}

type AvatarIndex = Record<string, AvatarRecord>

const memoryBlobs: Record<string, string> = {}
let dbPromise: Promise<IDBDatabase> | null = null

const getDb = (): Promise<IDBDatabase> => {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('indexedDB 不可用'))
  }
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const request = window.indexedDB.open(DB_NAME, 1)
      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: 'storageKey' })
        }
      }
      request.onerror = () => reject(request.error || new Error('打开 indexedDB 失败'))
      request.onsuccess = () => resolve(request.result)
    })
  }
  return dbPromise
}

const withStore = async <T>(mode: IDBTransactionMode, handler: (store: IDBObjectStore) => Promise<T> | T): Promise<T> => {
  const db = await getDb()
  return new Promise<T>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, mode)
    const store = tx.objectStore(STORE_NAME)
    const result = handler(store)
    tx.oncomplete = () => {
      Promise.resolve(result).then(resolve).catch(reject)
    }
    tx.onerror = () => reject(tx.error || new Error('indexedDB 事务失败'))
    tx.onabort = () => reject(tx.error || new Error('indexedDB 事务中止'))
  })
}

const saveToIndexedDB = async (storageKey: string, data: Uint8Array, contentType?: string) => {
  await withStore('readwrite', (store) => {
    store.put({ storageKey, data, contentType })
  })
}

const readFromIndexedDB = async (storageKey: string): Promise<{ data: Uint8Array; contentType?: string } | null> => {
  return withStore('readonly', (store) => {
    return new Promise((resolve, reject) => {
      const request = store.get(storageKey)
      request.onsuccess = () => {
        const value = request.result
        if (!value) {
          resolve(null)
          return
        }
        const buffer = value.data instanceof Uint8Array ? value.data : new Uint8Array(value.data)
        resolve({ data: buffer, contentType: value.contentType })
      }
      request.onerror = () => reject(request.error || new Error('读取 indexedDB 失败'))
    })
  })
}

const deleteFromIndexedDB = async (storageKey: string) => {
  await withStore('readwrite', (store) => {
    store.delete(storageKey)
  })
}

function readIndex(): AvatarIndex {
  if (typeof window === 'undefined' || !window.localStorage) {
    return {}
  }
  try {
    const raw = window.localStorage.getItem(INDEX_KEY)
    if (!raw) {
      return {}
    }
    return JSON.parse(raw) as AvatarIndex
  } catch (error) {
    console.warn('[AvatarCache] 读取索引失败，已重置:', error)
    return {}
  }
}

function writeIndex(index: AvatarIndex) {
  if (typeof window === 'undefined' || !window.localStorage) {
    return
  }
  try {
    window.localStorage.setItem(INDEX_KEY, JSON.stringify(index))
  } catch (error) {
    console.warn('[AvatarCache] 写入索引失败:', error)
  }
}

function toBase64(data: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < data.length; i += 1) {
    binary += String.fromCharCode(data[i])
  }
  return btoa(binary)
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value)
  const len = binary.length
  const bytes = new Uint8Array(len)
  for (let i = 0; i < len; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

function createBlobUrl(record: AvatarRecord, data: Uint8Array): string {
  // 确保数据可以正确转换为BlobPart
  const arrayBuffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
  const blob = new Blob([arrayBuffer], { type: record.contentType || 'application/octet-stream' })
  const url = URL.createObjectURL(blob)
  memoryBlobs[record.storageKey] = url
  return url
}

function createBlobUrlFromBase64(record: AvatarRecord, data: string): string {
  return createBlobUrl(record, fromBase64(data))
}

const revokeBlob = (key: string) => {
  const url = memoryBlobs[key]
  if (url) {
    URL.revokeObjectURL(url)
    delete memoryBlobs[key]
  }
}

export interface SaveAvatarOptions {
  userId: string
  objectKey: string
  data: Uint8Array
  filename?: string
  contentType?: string
  avatarType?: 'user' | 'group' // 头像类型，默认为'user'
}

export interface AvatarCacheResult {
  path: string
  webPath: string
}

export const AvatarCache = {
  async clear(userId: string) {
    const index = readIndex()
    const record = index[userId]
    if (!record) return

    if (record.storageType === 'indexedDB') {
      await deleteFromIndexedDB(record.storageKey).catch((error) => {
        console.warn('[AvatarCache] 清理 indexedDB 失败:', error)
      })
    } else if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.removeItem(record.storageKey)
    }

    revokeBlob(record.storageKey)
    delete index[userId]
    writeIndex(index)
  },

  async resolve(userId: string, objectKey: string, avatarType: 'user' | 'group' = 'user'): Promise<AvatarCacheResult | null> {
    const index = readIndex()
    const cacheKey = `${userId}_${avatarType}`
    const record = index[cacheKey]
    if (!record || record.key !== objectKey) {
      return null
    }

    if (record.storageType === 'indexedDB') {
      const stored = await readFromIndexedDB(record.storageKey)
      if (!stored) {
        delete index[userId]
        writeIndex(index)
        return null
      }
      if (memoryBlobs[record.storageKey]) {
        return { path: record.storageKey, webPath: memoryBlobs[record.storageKey] }
      }
      const url = createBlobUrl(record, stored.data)
      return { path: record.storageKey, webPath: url }
    }

    if (typeof window === 'undefined' || !window.localStorage) {
      return null
    }

    const stored = window.localStorage.getItem(record.storageKey)
    if (!stored) {
      delete index[cacheKey]
      writeIndex(index)
      return null
    }
    if (memoryBlobs[record.storageKey]) {
      return { path: record.storageKey, webPath: memoryBlobs[record.storageKey] }
    }
    const url = createBlobUrlFromBase64(record, stored)
    return { path: record.storageKey, webPath: url }
  },

  async save(options: SaveAvatarOptions): Promise<AvatarCacheResult> {
    const { userId, objectKey, data, contentType, avatarType = 'user' } = options

    const index = readIndex()
    const cacheKey = `${userId}_${avatarType}`
    const storageKey = `${DATA_PREFIX}${userId}_${avatarType}`
    const previous = index[cacheKey]

    if (previous) {
      if (previous.storageType === 'indexedDB') {
        await deleteFromIndexedDB(previous.storageKey).catch((error) => {
          console.warn('[AvatarCache] 删除旧 indexedDB 缓存失败:', error)
        })
      } else if (typeof window !== 'undefined' && window.localStorage) {
        window.localStorage.removeItem(previous.storageKey)
      }
      revokeBlob(previous.storageKey)
    }

    let record: AvatarRecord | null = null

    if (typeof window !== 'undefined' && window.localStorage) {
      try {
        window.localStorage.setItem(storageKey, toBase64(data))
        record = {
          key: objectKey,
          storageKey,
          contentType,
          storageType: 'localStorage'
        }
      } catch (error) {
        if (!(error instanceof DOMException) || error.name !== 'QuotaExceededError') {
          throw error
        }
        console.warn('[AvatarCache] localStorage 容量不足，切换 IndexedDB 存储')
      }
    }

    if (!record) {
      await saveToIndexedDB(storageKey, data, contentType).catch((err) => {
        console.error('[AvatarCache] 保存到 IndexedDB 失败:', err)
      })
      record = {
        key: objectKey,
        storageKey,
        contentType,
        storageType: 'indexedDB'
      }
    }

    index[cacheKey] = record
    writeIndex(index)

    revokeBlob(storageKey)

    if (record.storageType === 'indexedDB') {
      const url = createBlobUrl(record, data)
      return { path: storageKey, webPath: url }
    }

    const stored = window.localStorage.getItem(storageKey) as string
    const url = createBlobUrlFromBase64(record, stored)
    return { path: storageKey, webPath: url }
  }
}
