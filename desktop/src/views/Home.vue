<template>
  <div class="home">
    <div class="layout-container">
      <!-- 左侧菜单栏 -->
      <SideMenu />
      
      <!-- 右侧内容区域 -->
      <div class="main-content">
        <router-view />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onActivated, onDeactivated, onUnmounted } from 'vue'
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { setWindowSizeSafe, hasUserResized, installUserResizeListener, setWindowSizeDirect, setWindowSizeViaRust } from '@/utils/window'
import SideMenu from '../components/SideMenu.vue'

// 首页组件 - 包含左侧菜单和右侧二级路由内容

// 保存原始窗口状态
let originalSize: { width: number; height: number } | null = null;
let originalMaximized = false;
let windowStateInitialized = false;
let resizeUnlisten: (() => void) | null = null;

// 全局窗口监听器管理
let globalWindowListeners: (() => void)[] = [];

// 默认主窗口尺寸（降低高度以适应 Windows 高 DPI 屏幕）
const DEFAULT_MAIN_WINDOW_SIZE = { width: 1200, height: 720 };

// 设置主窗口尺寸
async function setMainWindowSize() {
  const logId = `HOME_RESIZE_${Date.now()}`;
  console.log('[Home] ============ setMainWindowSize START ============');
  console.log('[Home] Called at:', new Date().toISOString());
  console.log('[Home] Call stack:', new Error().stack);

  try {
    const currentWindow = getCurrentWebviewWindow();

    // 先确保窗口可调整（解除登录页面的限制）
    try {
      await currentWindow.setResizable(true);
      console.log('[Home] Window set to resizable: SUCCESS');
      // 添加小延迟确保 resizable 状态生效
      await new Promise(resolve => setTimeout(resolve, 50));
    } catch (error) {
      console.log('[Home] setResizable failed:', error);
    }

    const userResized = hasUserResized();
    console.log('[Home] User resized status:', userResized);

    // 临时强制执行resize，忽略userResized标志（用于调试）
    const FORCE_RESIZE = true; // 调试标志
    if (userResized && !FORCE_RESIZE) {
      console.log('[Home] User has resized, skipping auto-resize');
      return
    } else if (userResized && FORCE_RESIZE) {
      console.log('[Home] User has resized but FORCE_RESIZE is enabled, continuing...');
    }

    // 优先使用 Rust 端设置窗口尺寸（更可靠）
    console.log('[Home] About to call setWindowSizeViaRust with:', DEFAULT_MAIN_WINDOW_SIZE);
    console.log('[Home] Calling setWindowSizeViaRust NOW...');

    try {
      const rustSuccess = await setWindowSizeViaRust(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)
      console.log('[Home] setWindowSizeViaRust returned:', rustSuccess);

      if (!rustSuccess) {
        // 如果 Rust 端失败，尝试直接设置
        console.log('[Home] Rust method failed, trying direct method...');
        const directSuccess = await setWindowSizeDirect(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)
        console.log('[Home] Direct method result:', directSuccess);

        if (!directSuccess) {
          // 最后使用安全方法
          console.log('[Home] Direct method failed, using safe method...');
          await setWindowSizeSafe(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)
          console.log('[Home] Safe method completed');
        }
      }
    } catch (invokeError) {
      console.error('[Home] Error calling setWindowSizeViaRust:', invokeError);
      console.error('[Home] Error stack:', invokeError.stack);
      // 降级到直接方法
      console.log('[Home] Fallback to direct method due to invoke error');
      await setWindowSizeDirect(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height);
    }
  } catch (error) {
    console.error('[Home] Failed to set window size:', error);
    console.error('[Home] Error stack:', error.stack);
  } finally {
    console.log('[Home] ============ setMainWindowSize END ============');
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  const logId = `HOME_PREPARE_${Date.now()}`;
  console.log('[Home] ============ prepareWindowOnLogin START ============');
  console.log('[Home] logId:', logId);
  console.log('[Home] Called at:', new Date().toISOString());

  try {
    const currentWindow = getCurrentWebviewWindow();
    console.log('[Home] Got current window');

    const isCurrentlyMaximized = await currentWindow.isMaximized();
    console.log('[Home] isMaximized result:', isCurrentlyMaximized);

    const currentSize = await currentWindow.innerSize();
    console.log('[Home] innerSize result:', currentSize);

    const userResized = hasUserResized();
    console.log('[Home] hasUserResized result:', userResized);

    console.log('[Home] Current window state summary:', {
      maximized: isCurrentlyMaximized,
      size: currentSize,
      userResized: userResized,
      windowStateInitialized: windowStateInitialized
    });

    // 调试：强制执行
    const FORCE_EXECUTE = true;

    // 如果不是最大化，设置为默认主窗口尺寸
    if (!isCurrentlyMaximized && !userResized) {
      console.log('[Home] Conditions met naturally, calling setMainWindowSize');
      await setMainWindowSize();
    } else if (FORCE_EXECUTE && !isCurrentlyMaximized) {
      console.log('[Home] FORCE_EXECUTE enabled, calling setMainWindowSize despite userResized:', userResized);
      await setMainWindowSize();
    } else {
      console.log('[Home] Skipping resize - conditions not met');
      console.log('[Home]   - isMaximized:', isCurrentlyMaximized);
      console.log('[Home]   - userResized:', userResized);
      console.log('[Home]   - FORCE_EXECUTE:', FORCE_EXECUTE);
    }

    windowStateInitialized = true;
    console.log('[Home] windowStateInitialized set to true');
  } catch (error) {
    console.error('[Home] prepareWindowOnLogin error:', error);
    console.error('[Home] Error stack:', error.stack);
    windowStateInitialized = true;
  } finally {
    console.log('[Home] ============ prepareWindowOnLogin END ============');
  }
}

// 清理所有窗口监听器
function clearAllWindowListeners() {
  globalWindowListeners.forEach(unlisten => {
    try {
      unlisten();
    } catch (error) {
    }
  });
  globalWindowListeners = [];
  
  // 清理旧的resize监听器
  if (resizeUnlisten) {
    try {
      resizeUnlisten();
    } catch (error) {
    }
    resizeUnlisten = null;
  }
}

// 组件激活时（用于 keep-alive）
onActivated(() => {
  const logId = `HOME_ACTIVATED_${Date.now()}`;
  console.log('[Home] ==========================================');
  console.log('[Home] Component ACTIVATED at:', new Date().toISOString());
  console.log('[Home] logId:', logId);
  console.log('[Home] windowStateInitialized before:', windowStateInitialized);

  // 重置状态，确保每次激活都重新设置窗口
  windowStateInitialized = false;
  console.log('[Home] windowStateInitialized reset to false');

  // 立即设置窗口尺寸，避免闪烁
  console.log('[Home] Calling prepareWindowOnLogin from onActivated...');
  prepareWindowOnLogin();
})

// 组件失活时（用于 keep-alive）
onDeactivated(() => {
  const logId = `HOME_DEACTIVATED_${Date.now()}`;
  console.log('[Home] Component DEACTIVATED at:', new Date().toISOString());
  console.log('[Home] logId:', logId);
  clearAllWindowListeners();
})

// 组件挂载时
onMounted(() => {
  const logId = `HOME_MOUNTED_${Date.now()}`;
  console.log('[Home] ==========================================');
  console.log('[Home] Component MOUNTED at:', new Date().toISOString());
  console.log('[Home] logId:', logId);

  console.log('[Home] Installing user resize listener...');
  void installUserResizeListener()

  // 立即设置窗口尺寸，避免闪烁
  console.log('[Home] Calling prepareWindowOnLogin from onMounted...');
  prepareWindowOnLogin();
});

// 组件卸载时
onUnmounted(() => {
  const logId = `HOME_UNMOUNTED_${Date.now()}`;
  clearAllWindowListeners();
});
</script>

<style lang="scss" scoped>
.home {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.layout-container {
  display: flex;
  width: 100%;
  height: 100%;
  position: relative;
}

.main-content {
  flex: 1;
  width: calc(100% - 100px);
  background: #ffffff;
  overflow: hidden;
  position: relative;
  z-index: 1;
  min-width: 0;
  pointer-events: auto;
}

// 确保子路由内容正确显示
:deep(.router-view) {
  width: 100%;
  height: 100%;
}
</style>
