import { afterEach, beforeEach } from 'vitest';

const createStorageMock = () => {
  let data = new Map<string, string>();

  return {
    get length() {
      return data.size;
    },
    clear() {
      data = new Map<string, string>();
    },
    getItem(key: string) {
      return data.get(key) ?? null;
    },
    key(index: number) {
      return Array.from(data.keys())[index] ?? null;
    },
    removeItem(key: string) {
      data.delete(key);
    },
    setItem(key: string, value: string) {
      data.set(key, String(value));
    },
  };
};

beforeEach(() => {
  Object.defineProperty(window, 'localStorage', {
    configurable: true,
    value: createStorageMock(),
  });
});

afterEach(() => {
  window.localStorage.clear();
});
