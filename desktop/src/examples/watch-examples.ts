// @ts-nocheck

/**
 * Vue 3 Watch API 使用示例
 * 展示各种 watch 模式和最佳实践
 */

import { ref, computed, reactive, watch, watchEffect } from 'vue';
import {
  createWatcherManager,
  createDebouncedWatcher,
  createThrottledWatcher,
  createConditionalWatcher,
  createBatchWatcher,
  createOnceWatcher,
  createAsyncWatcher,
  createSafeWatcher,
  createWatcherChain,
  watchPatterns
} from '@/utils/watch';
import { get } from '../api/http';

// 示例数据
const searchQuery = ref('');
const userSettings = reactive({
  theme: 'light',
  language: 'zh-CN',
  autoSave: true
});
const isLoggedIn = ref(false);
const apiData = ref(null);

/**
 * 示例1: 基础 watch 用法
 */
export function basicWatchExample() {
  // 监听单个 ref
  const stopWatcher1 = watch(searchQuery, (newValue, oldValue) => {
  });

  // 监听多个源
  const stopWatcher2 = watch(
    [searchQuery, isLoggedIn],
    ([newQuery, newLoginStatus], [oldQuery, oldLoginStatus]) => {
    }
  );

  // 监听响应式对象
  const stopWatcher3 = watch(
    userSettings,
    (newSettings, oldSettings) => {
    },
    { deep: true }
  );

  return () => {
    stopWatcher1();
    stopWatcher2();
    stopWatcher3();
  };
}

/**
 * 示例2: watchEffect 用法
 */
export function watchEffectExample() {
  const stopEffect = watchEffect(() => {
    // 自动追踪依赖
    if (isLoggedIn.value && searchQuery.value) {
    }
  });

  return stopEffect;
}

/**
 * 示例3: 防抖监听器 - 搜索输入
 */
export function debouncedSearchExample() {
  const stopWatcher = createDebouncedWatcher(
    searchQuery,
    (newQuery) => {
      if (newQuery.trim()) {
        // 这里可以调用搜索 API
      }
    },
    500 // 500ms 防抖
  );

  return stopWatcher;
}

/**
 * 示例4: 节流监听器 - 滚动事件
 */
export function throttledScrollExample() {
  const scrollY = ref(0);

  const stopWatcher = createThrottledWatcher(
    scrollY,
    (newY) => {
      // 更新导航栏状态等
    },
    100 // 100ms 节流
  );

  // 模拟滚动事件
  const handleScroll = () => {
    scrollY.value = window.scrollY;
  };

  window.addEventListener('scroll', handleScroll);

  return () => {
    stopWatcher();
    window.removeEventListener('scroll', handleScroll);
  };
}

/**
 * 示例5: 条件监听器
 */
export function conditionalWatchExample() {
  const stopWatcher = createConditionalWatcher(
    userSettings,
    () => isLoggedIn.value, // 只有登录时才监听设置变化
    (newSettings) => {
      // 保存设置到服务器
    },
    { deep: true }
  );

  return stopWatcher;
}

/**
 * 示例6: 批量监听器
 */
export function batchWatchExample() {
  const name = ref('');
  const email = ref('');
  const age = ref(0);

  const stopWatcher = createBatchWatcher(
    [name, email, age],
    ([newName, newEmail, newAge], [oldName, oldEmail, oldAge]) => {
    }
  );

  return stopWatcher;
}

/**
 * 示例7: 一次性监听器
 */
export function onceWatchExample() {
  const stopWatcher = createOnceWatcher(
    isLoggedIn,
    (isLoggedIn) => {
      if (isLoggedIn) {
        // 加载用户数据、设置等
      }
    },
    { immediate: true }
  );

  return stopWatcher;
}

/**
 * 示例8: 异步监听器
 */
export function asyncWatchExample() {
  const userId = ref<string | null>(null);

  const stopWatcher = createAsyncWatcher(
    userId,
    async (newUserId, oldUserId, onCleanup) => {
      if (newUserId) {
        
        // 模拟 API 调用
        const cancellation = { cancelled: false };
        onCleanup(() => {
          cancellation.cancelled = true;
        });

        try {
          const response = await get(`/api/users/${newUserId}`);
          if (cancellation.cancelled) {
            return;
          }
          apiData.value = response.data;
        } catch (error) {
          if (!cancellation.cancelled) {
          }
        }
      }
    }
  );

  return stopWatcher;
}

/**
 * 示例9: 错误处理监听器
 */
export function safeWatchExample() {
  const riskyData = ref<any>(null);

  const stopWatcher = createSafeWatcher(
    riskyData,
    (newData) => {
      // 可能抛出错误的操作
      const result = newData.someProperty.deepProperty.value;
    },
    (error) => {
      // 可以发送错误报告、显示用户友好的错误信息等
    }
  );

  return stopWatcher;
}

/**
 * 示例10: 监听器链
 */
export function watcherChainExample() {
  const input = ref('');

  const chain = createWatcherChain(input)
    .debounce((value) => {
    }, 300)
    .condition(
      () => input.value.length > 2,
      (value) => {
      }
    )
    .once((value) => {
    });

  return () => chain.stop();
}

/**
 * 示例11: 监听器管理器
 */
export function watcherManagerExample() {
  const manager = createWatcherManager();

  // 添加多个监听器
  manager.add(watch(searchQuery, (value) => {
  }));

  manager.add(watch(isLoggedIn, (status) => {
  }));

  manager.add(watchEffect(() => {
  }));


  // 清理所有监听器
  return () => manager.clear();
}

/**
 * 示例12: 使用预定义模式
 */
export function watchPatternsExample() {
  // 立即执行的监听器
  const stopImmediate = watchPatterns.immediate(
    userSettings,
    (settings) => {
    },
    { deep: true }
  );

  // 深度监听
  const stopDeep = watchPatterns.deep(
    userSettings,
    (settings) => {
    }
  );

  // 同步执行
  const stopSync = watchPatterns.sync(
    searchQuery,
    (query) => {
    }
  );

  return () => {
    stopImmediate();
    stopDeep();
    stopSync();
  };
}

/**
 * 示例13: 计算属性与监听器结合
 */
export function computedWithWatchExample() {
  const firstName = ref('');
  const lastName = ref('');

  // 计算属性
  const fullName = computed(() => {
    return `${firstName.value} ${lastName.value}`.trim();
  });

  // 监听计算属性
  const stopWatcher = watch(fullName, (newFullName, oldFullName) => {
    if (newFullName && newFullName !== oldFullName) {
    }
  });

  return stopWatcher;
}

// 导出所有示例函数
export const watchExamples = {
  basic: basicWatchExample,
  watchEffect: watchEffectExample,
  debouncedSearch: debouncedSearchExample,
  throttledScroll: throttledScrollExample,
  conditional: conditionalWatchExample,
  batch: batchWatchExample,
  once: onceWatchExample,
  async: asyncWatchExample,
  safe: safeWatchExample,
  chain: watcherChainExample,
  manager: watcherManagerExample,
  patterns: watchPatternsExample,
  computedWithWatch: computedWithWatchExample
};
