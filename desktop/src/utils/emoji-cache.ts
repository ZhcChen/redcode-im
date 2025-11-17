const INDEX_KEY = 'emoji_cache_index_v1'
const DATA_PREFIX = 'emoji_cache_data_'
const DB_NAME = 'emoji-cache'
const STORE_NAME = 'emojis'

type StorageType = 'localStorage' | 'indexedDB'

interface EmojiRecord {
  imageUrl: string
  storageKey: string
  contentType?: string
  storageType?: StorageType
}

type EmojiIndex = Record<string, EmojiRecord>

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

function readIndex(): EmojiIndex {
  if (typeof window === 'undefined' || !window.localStorage) {
    return {}
  }
  try {
    const raw = window.localStorage.getItem(INDEX_KEY)
    if (!raw) {
      return {}
    }
    return JSON.parse(raw) as EmojiIndex
  } catch (error) {
    return {}
  }
}

function writeIndex(index: EmojiIndex) {
  if (typeof window === 'undefined' || !window.localStorage) {
    return
  }
  try {
    window.localStorage.setItem(INDEX_KEY, JSON.stringify(index))
  } catch (error) {
    // 忽略存储错误
  }
}

function toBase64(data: Uint8Array): string {
  const bytes = Array.from(data)
  const binary = bytes.map((byte) => String.fromCharCode(byte)).join('')
  return btoa(binary)
}

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

function createBlobUrl(record: EmojiRecord, data: Uint8Array): string {
  const blob = new Blob([data], { type: record.contentType || 'image/png' })
  const url = URL.createObjectURL(blob)
  memoryBlobs[record.storageKey] = url
  return url
}

function createBlobUrlFromBase64(record: EmojiRecord, base64: string): string {
  const data = base64ToUint8Array(base64)
  return createBlobUrl(record, data)
}

function revokeBlob(storageKey: string) {
  if (memoryBlobs[storageKey]) {
    URL.revokeObjectURL(memoryBlobs[storageKey])
    delete memoryBlobs[storageKey]
  }
}

export interface EmojiCacheResult {
  path: string
  webPath: string
}

export interface SaveEmojiOptions {
  imageUrl: string
  data: Uint8Array
  contentType?: string
}

export const EmojiCache = {
  async clear(imageUrl: string) {
    const index = readIndex()
    const cacheKey = imageUrl
    const record = index[cacheKey]
    if (!record) return

    if (record.storageType === 'indexedDB') {
      await deleteFromIndexedDB(record.storageKey).catch(() => {})
    } else if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.removeItem(record.storageKey)
    }

    revokeBlob(record.storageKey)
    delete index[cacheKey]
    writeIndex(index)
  },

  async resolve(imageUrl: string): Promise<EmojiCacheResult | null> {
    const index = readIndex()
    const cacheKey = imageUrl
    const record = index[cacheKey]
    if (!record || record.imageUrl !== imageUrl) {
      return null
    }

    if (record.storageType === 'indexedDB') {
      const stored = await readFromIndexedDB(record.storageKey)
      if (!stored) {
        delete index[cacheKey]
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

  async save(options: SaveEmojiOptions): Promise<EmojiCacheResult> {
    const { imageUrl, data, contentType } = options

    const index = readIndex()
    const cacheKey = imageUrl
    // 使用简单的 hash 函数生成 storageKey
    let hash = 0
    for (let i = 0; i < imageUrl.length; i++) {
      const char = imageUrl.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // Convert to 32bit integer
    }
    const storageKey = `${DATA_PREFIX}${Math.abs(hash).toString(16)}`
    const previous = index[cacheKey]

    if (previous) {
      if (previous.storageType === 'indexedDB') {
        await deleteFromIndexedDB(previous.storageKey).catch(() => {})
      } else if (typeof window !== 'undefined' && window.localStorage) {
        window.localStorage.removeItem(previous.storageKey)
      }
      revokeBlob(previous.storageKey)
    }

    let record: EmojiRecord | null = null

    if (typeof window !== 'undefined' && window.localStorage) {
      try {
        window.localStorage.setItem(storageKey, toBase64(data))
        record = {
          imageUrl,
          storageKey,
          contentType,
          storageType: 'localStorage'
        }
      } catch (error) {
        if (!(error instanceof DOMException) || error.name !== 'QuotaExceededError') {
          throw error
        }
      }
    }

    if (!record) {
      await saveToIndexedDB(storageKey, data, contentType).catch(() => {})
      record = {
        imageUrl,
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

