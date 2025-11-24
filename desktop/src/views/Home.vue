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
  try {
    const currentWindow = getCurrentWebviewWindow();

    // 先确保窗口可调整（解除登录页面的限制）
    try {
      await currentWindow.setResizable(true);
      // 添加小延迟确保 resizable 状态生效
      await new Promise(resolve => setTimeout(resolve, 50));
    } catch (error) {
      console.warn('[Home] setResizable failed:', error);
    }

    const userResized = hasUserResized();
    if (userResized) {
      return
    }

    // 优先使用 Rust 端设置窗口尺寸（更可靠）
    const rustSuccess = await setWindowSizeViaRust(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)

    if (!rustSuccess) {
      // 如果 Rust 端失败，尝试直接设置
      const directSuccess = await setWindowSizeDirect(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)

      if (!directSuccess) {
        // 最后使用安全方法
        await setWindowSizeSafe(DEFAULT_MAIN_WINDOW_SIZE.width, DEFAULT_MAIN_WINDOW_SIZE.height)
      }
    }
  } catch (error) {
    console.error('[Home] Failed to set window size:', error);
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  try {
    const currentWindow = getCurrentWebviewWindow();
    const isCurrentlyMaximized = await currentWindow.isMaximized();

    // 如果不是最大化且用户没有手动调整过，设置为默认主窗口尺寸
    if (!isCurrentlyMaximized && !hasUserResized()) {
      await setMainWindowSize();
    }

    windowStateInitialized = true;
  } catch (error) {
    console.error('[Home] prepareWindowOnLogin error:', error);
    windowStateInitialized = true;
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
  // 重置状态，确保每次激活都重新设置窗口
  windowStateInitialized = false;

  // 立即设置窗口尺寸，避免闪烁
  prepareWindowOnLogin();
})

// 组件失活时（用于 keep-alive）
onDeactivated(() => {
  clearAllWindowListeners();
})

// 组件挂载时
onMounted(() => {
  void installUserResizeListener()

  // 立即设置窗口尺寸，避免闪烁
  prepareWindowOnLogin();
});

// 组件卸载时
onUnmounted(() => {
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
