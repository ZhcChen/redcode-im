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
    console.log(`搜索查询从 "${oldValue}" 变为 "${newValue}"`);
  });

  // 监听多个源
  const stopWatcher2 = watch(
    [searchQuery, isLoggedIn],
    ([newQuery, newLoginStatus], [oldQuery, oldLoginStatus]) => {
      console.log('搜索查询或登录状态发生变化');
    }
  );

  // 监听响应式对象
  const stopWatcher3 = watch(
    userSettings,
    (newSettings, oldSettings) => {
      console.log('用户设置发生变化:', newSettings);
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
      console.log(`已登录用户搜索: ${searchQuery.value}`);
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
        console.log(`执行搜索: ${newQuery}`);
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
      console.log(`滚动位置: ${newY}`);
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
      console.log('已登录用户的设置发生变化:', newSettings);
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
      console.log('用户信息发生变化:', {
        name: { old: oldName, new: newName },
        email: { old: oldEmail, new: newEmail },
        age: { old: oldAge, new: newAge }
      });
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
        console.log('用户首次登录，执行初始化操作');
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
        console.log(`加载用户 ${newUserId} 的数据`);
        
        // 模拟 API 调用
        const controller = new AbortController();
        onCleanup(() => controller.abort());

        try {
          const response = await fetch(`/api/users/${newUserId}`, {
            signal: controller.signal
          });
          const userData = await response.json();
          apiData.value = userData;
          console.log('用户数据加载完成:', userData);
        } catch (error) {
          if (error.name !== 'AbortError') {
            console.error('加载用户数据失败:', error);
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
      console.log('处理结果:', result);
    },
    (error) => {
      console.error('监听器执行出错:', error.message);
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
      console.log('防抖处理:', value);
    }, 300)
    .condition(
      () => input.value.length > 2,
      (value) => {
        console.log('长度大于2的输入:', value);
      }
    )
    .once((value) => {
      console.log('首次输入:', value);
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
    console.log('搜索查询变化:', value);
  }));

  manager.add(watch(isLoggedIn, (status) => {
    console.log('登录状态变化:', status);
  }));

  manager.add(watchEffect(() => {
    console.log('响应式效果:', searchQuery.value, isLoggedIn.value);
  }));

  console.log(`管理器中有 ${manager.size()} 个监听器`);

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
      console.log('立即执行 - 当前设置:', settings);
    },
    { deep: true }
  );

  // 深度监听
  const stopDeep = watchPatterns.deep(
    userSettings,
    (settings) => {
      console.log('深度监听 - 设置变化:', settings);
    }
  );

  // 同步执行
  const stopSync = watchPatterns.sync(
    searchQuery,
    (query) => {
      console.log('同步执行 - 搜索查询:', query);
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
      console.log(`全名从 "${oldFullName}" 变为 "${newFullName}"`);
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
