/**
 * Vue 3 Watch API 增强类型定义
 * 提供更严格和实用的 watch 相关类型
 */

// @ts-nocheck
import type { Ref, ComputedRef } from 'vue';

// 基础 Watch 类型
export type WatchSource<T = any> = 
  | Ref<T> 
  | ComputedRef<T> 
  | (() => T);

export type MultiWatchSources = (WatchSource<unknown> | object)[];

// Watch 回调函数类型
export type WatchCallback<V = any, OV = any> = (
  value: V,
  oldValue: OV,
  onCleanup: OnCleanup
) => any;

export type MultiWatchCallback<T extends Readonly<MultiWatchSources>, Immediate extends Readonly<boolean> = false> = (
  value: MapSources<T, false>,
  oldValue: MapSources<T, Immediate>,
  onCleanup: OnCleanup
) => any;

// 清理函数类型
export type OnCleanup = (cleanupFn: () => void) => void;

// Watch 停止句柄
export type WatchStopHandle = () => void;

// Watch 选项
export interface WatchOptions<Immediate = boolean> {
  immediate?: Immediate;
  deep?: boolean;
  flush?: 'pre' | 'post' | 'sync';
  onTrack?: (event: DebuggerEvent) => void;
  onTrigger?: (event: DebuggerEvent) => void;
}

// WatchEffect 相关类型
export type WatchEffectCallback = (onCleanup: OnCleanup) => void;

export interface WatchEffectOptions {
  flush?: 'pre' | 'post' | 'sync';
  onTrack?: (event: DebuggerEvent) => void;
  onTrigger?: (event: DebuggerEvent) => void;
}

// 调试相关类型
export interface DebuggerEvent {
  effect: any;
  target: object;
  type: 'get' | 'set' | 'add' | 'delete' | 'clear';
  key: any;
  newValue?: any;
  oldValue?: any;
  oldTarget?: Map<any, any> | Set<any>;
}

// 工具类型
export type MapSources<T extends Readonly<MultiWatchSources>, Immediate> = {
  [K in keyof T]: T[K] extends WatchSource<infer V>
    ? Immediate extends true
      ? V | undefined
      : V
    : T[K] extends object
    ? Immediate extends true
      ? T[K] | undefined
      : T[K]
    : never;
};

// 常用的 Watch 模式类型
export interface WatchPatterns {
  // 立即执行的 watch
  immediate<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T, T | undefined>,
    options?: Omit<WatchOptions<true>, 'immediate'>
  ): WatchStopHandle;

  // 深度监听的 watch
  deep<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'deep'>
  ): WatchStopHandle;

  // 同步执行的 watch
  sync<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'flush'>
  ): WatchStopHandle;

  // 后置执行的 watch
  post<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    options?: Omit<WatchOptions, 'flush'>
  ): WatchStopHandle;
}

// 增强的 Watch 函数类型
export interface EnhancedWatch {
  // 单个源的 watch
  <T, Immediate extends Readonly<boolean> = false>(
    source: WatchSource<T>,
    cb: WatchCallback<T, Immediate extends true ? T | undefined : T>,
    options?: WatchOptions<Immediate>
  ): WatchStopHandle;

  // 多个源的 watch
  <T extends Readonly<MultiWatchSources>, Immediate extends Readonly<boolean> = false>(
    sources: T,
    cb: MultiWatchCallback<T, Immediate>,
    options?: WatchOptions<Immediate>
  ): WatchStopHandle;

  // 对象的 watch
  <T extends object, Immediate extends Readonly<boolean> = false>(
    source: T,
    cb: WatchCallback<T, Immediate extends true ? T | undefined : T>,
    options?: WatchOptions<Immediate>
  ): WatchStopHandle;
}

// 常用的监听器类型
export type StateWatcher<T> = (newValue: T, oldValue: T) => void;
export type EffectWatcher = (onCleanup: OnCleanup) => void;
export type ComputedWatcher<T> = () => T;

// 监听器管理器类型
export interface WatcherManager {
  watchers: Set<WatchStopHandle>;
  add(watcher: WatchStopHandle): void;
  remove(watcher: WatchStopHandle): void;
  clear(): void;
  size(): number;
}

// 条件监听类型
export type ConditionalWatcher<T> = {
  condition: () => boolean;
  watcher: WatchCallback<T>;
};

// 防抖监听类型
export type DebouncedWatcher<T> = {
  delay: number;
  watcher: WatchCallback<T>;
};

// 节流监听类型
export type ThrottledWatcher<T> = {
  interval: number;
  watcher: WatchCallback<T>;
};

// 批量监听类型
export interface BatchWatcher {
  sources: WatchSource[];
  callback: (values: any[], oldValues: any[]) => void;
  options?: WatchOptions;
}

// 监听器配置类型
export interface WatcherConfig<T = any> {
  source: WatchSource<T>;
  callback: WatchCallback<T>;
  options?: WatchOptions;
  enabled?: boolean;
  name?: string;
}

// 监听器组类型
export interface WatcherGroup {
  name: string;
  watchers: WatcherConfig[];
  enabled: boolean;
}

// 导出增强的监听器工具类型
export interface WatchUtils {
  // 创建条件监听器
  createConditionalWatcher<T>(
    source: WatchSource<T>,
    condition: () => boolean,
    callback: WatchCallback<T>,
    options?: WatchOptions
  ): WatchStopHandle;

  // 创建防抖监听器
  createDebouncedWatcher<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    delay: number,
    options?: WatchOptions
  ): WatchStopHandle;

  // 创建节流监听器
  createThrottledWatcher<T>(
    source: WatchSource<T>,
    callback: WatchCallback<T>,
    interval: number,
    options?: WatchOptions
  ): WatchStopHandle;

  // 创建批量监听器
  createBatchWatcher(
    sources: WatchSource[],
    callback: (values: any[], oldValues: any[]) => void,
    options?: WatchOptions
  ): WatchStopHandle;

  // 创建监听器管理器
  createWatcherManager(): WatcherManager;
}
