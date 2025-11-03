/**
 * Vue 3 Watch 工具函数
 * 提供增强的 watch 功能和常用模式
 */

// @ts-nocheck
import { watch, watchEffect, type Ref, type ComputedRef } from 'vue';
import type {
  WatchSource,
  WatchCallback,
  WatchOptions,
  WatchStopHandle,
  WatcherManager,
  OnCleanup
} from '@/types/watch';

/**
 * 创建监听器管理器
 * 用于统一管理多个监听器的生命周期
 */
export function createWatcherManager(): WatcherManager {
  const watchers = new Set<WatchStopHandle>();

  return {
    watchers,
    add(watcher: WatchStopHandle) {
      watchers.add(watcher);
    },
    remove(watcher: WatchStopHandle) {
      watchers.delete(watcher);
      watcher();
    },
    clear() {
      watchers.forEach(watcher => watcher());
      watchers.clear();
    },
    size() {
      return watchers.size;
    }
  };
}

/**
 * 创建防抖监听器
 * 在指定延迟后执行回调，如果在延迟期间再次触发则重新计时
 */
export function createDebouncedWatcher<T>(
  source: WatchSource<T>,
  callback: WatchCallback<T>,
  delay: number = 300,
  options?: WatchOptions
): WatchStopHandle {
  let timeoutId: number | null = null;

  return watch(
    source,
    (newValue, oldValue, onCleanup) => {
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }

      timeoutId = window.setTimeout(() => {
        callback(newValue, oldValue, onCleanup);
        timeoutId = null;
      }, delay);

      onCleanup(() => {
        if (timeoutId !== null) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
      });
    },
    options
  );
}

/**
 * 创建节流监听器
 * 在指定时间间隔内最多执行一次回调
 */
export function createThrottledWatcher<T>(
  source: WatchSource<T>,
  callback: WatchCallback<T>,
  interval: number = 300,
  options?: WatchOptions
): WatchStopHandle {
  let lastExecTime = 0;
  let timeoutId: number | null = null;

  return watch(
    source,
    (newValue, oldValue, onCleanup) => {
      const now = Date.now();
      const timeSinceLastExec = now - lastExecTime;

      if (timeSinceLastExec >= interval) {
        // 立即执行
        callback(newValue, oldValue, onCleanup);
        lastExecTime = now;
      } else {
        // 延迟执行
        if (timeoutId !== null) {
          clearTimeout(timeoutId);
        }

        timeoutId = window.setTimeout(() => {
          callback(newValue, oldValue, onCleanup);
          lastExecTime = Date.now();
          timeoutId = null;
        }, interval - timeSinceLastExec);
      }

      onCleanup(() => {
        if (timeoutId !== null) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
      });
    },
    options
  );
}

/**
 * 创建条件监听器
 * 只有当条件为真时才执行回调
 */
export function createConditionalWatcher<T>(
  source: WatchSource<T>,
  condition: () => boolean,
  callback: WatchCallback<T>,
  options?: WatchOptions
): WatchStopHandle {
  return watch(
    source,
    (newValue, oldValue, onCleanup) => {
      if (condition()) {
        callback(newValue, oldValue, onCleanup);
      }
    },
    options
  );
}

/**
 * 创建批量监听器
 * 同时监听多个源，当任一源变化时执行回调
 */
export function createBatchWatcher(
  sources: WatchSource[],
  callback: (values: any[], oldValues: any[]) => void,
  options?: WatchOptions
): WatchStopHandle {
  return watch(
    sources,
    (newValues, oldValues, onCleanup) => {
      callback(newValues, oldValues);
    },
    options
  );
}

/**
 * 创建一次性监听器
 * 只执行一次回调后自动停止监听
 */
export function createOnceWatcher<T>(
  source: WatchSource<T>,
  callback: WatchCallback<T>,
  options?: WatchOptions
): WatchStopHandle {
  let stopHandle: WatchStopHandle;

  stopHandle = watch(
    source,
    (newValue, oldValue, onCleanup) => {
      callback(newValue, oldValue, onCleanup);
      stopHandle();
    },
    options
  );

  return stopHandle;
}

/**
 * 创建值变化监听器
 * 只有当值真正发生变化时才执行回调（深度比较）
 */
export function createValueChangeWatcher<T>(
  source: WatchSource<T>,
  callback: WatchCallback<T>,
  options?: WatchOptions
): WatchStopHandle {
  return watch(
    source,
    (newValue, oldValue, onCleanup) => {
      // 简单的深度比较
      if (JSON.stringify(newValue) !== JSON.stringify(oldValue)) {
        callback(newValue, oldValue, onCleanup);
      }
    },
    options
  );
}

/**
 * 创建异步监听器
 * 支持异步回调函数
 */
export function createAsyncWatcher<T>(
  source: WatchSource<T>,
  callback: (newValue: T, oldValue: T, onCleanup: OnCleanup) => Promise<void>,
  options?: WatchOptions
): WatchStopHandle {
  return watch(
    source,
    async (newValue, oldValue, onCleanup) => {
      try {
        await callback(newValue, oldValue, onCleanup);
      } catch (error) {
        console.error('Async watcher error:', error);
      }
    },
    options
  );
}

/**
 * 创建错误处理监听器
 * 自动捕获和处理回调中的错误
 */
export function createSafeWatcher<T>(
  source: WatchSource<T>,
  callback: WatchCallback<T>,
  errorHandler?: (error: Error) => void,
  options?: WatchOptions
): WatchStopHandle {
  return watch(
    source,
    (newValue, oldValue, onCleanup) => {
      try {
        callback(newValue, oldValue, onCleanup);
      } catch (error) {
        if (errorHandler) {
          errorHandler(error as Error);
        } else {
          console.error('Watcher error:', error);
        }
      }
    },
    options
  );
}

/**
 * 创建链式监听器
 * 支持链式调用多个监听器
 */
export class WatcherChain<T> {
  private source: WatchSource<T>;
  private watchers: WatchStopHandle[] = [];

  constructor(source: WatchSource<T>) {
    this.source = source;
  }

  debounce(callback: WatchCallback<T>, delay: number = 300, options?: WatchOptions) {
    const watcher = createDebouncedWatcher(this.source, callback, delay, options);
    this.watchers.push(watcher);
    return this;
  }

  throttle(callback: WatchCallback<T>, interval: number = 300, options?: WatchOptions) {
    const watcher = createThrottledWatcher(this.source, callback, interval, options);
    this.watchers.push(watcher);
    return this;
  }

  condition(condition: () => boolean, callback: WatchCallback<T>, options?: WatchOptions) {
    const watcher = createConditionalWatcher(this.source, condition, callback, options);
    this.watchers.push(watcher);
    return this;
  }

  once(callback: WatchCallback<T>, options?: WatchOptions) {
    const watcher = createOnceWatcher(this.source, callback, options);
    this.watchers.push(watcher);
    return this;
  }

  safe(callback: WatchCallback<T>, errorHandler?: (error: Error) => void, options?: WatchOptions) {
    const watcher = createSafeWatcher(this.source, callback, errorHandler, options);
    this.watchers.push(watcher);
    return this;
  }

  stop() {
    this.watchers.forEach(watcher => watcher());
    this.watchers = [];
  }
}

/**
 * 创建监听器链
 */
export function createWatcherChain<T>(source: WatchSource<T>): WatcherChain<T> {
  return new WatcherChain(source);
}

/**
 * 常用的监听器模式
 */
export const watchPatterns = {
  // 立即执行的监听器
  immediate<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T, T | undefined>,
    options?: Omit<WatchOptions, 'immediate'>
  ) {
    return watch(source, callback, { ...options, immediate: true });
  },

  // 深度监听
  deep<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'deep'>
  ) {
    return watch(source, callback, { ...options, deep: true });
  },

  // 同步执行
  sync<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'flush'>
  ) {
    return watch(source, callback, { ...options, flush: 'sync' });
  },

  // 后置执行
  post<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'flush'>
  ) {
    return watch(source, callback, { ...options, flush: 'post' });
  }
};
