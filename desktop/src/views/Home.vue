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
import SideMenu from '../components/SideMenu.vue'

// 首页组件 - 包含左侧菜单和右侧二级路由内容

// 保存原始窗口状态
let originalSize: { width: number; height: number } | null = null;
let originalMaximized = false;
let windowStateInitialized = false;
let resizeUnlisten: (() => void) | null = null;

// 全局窗口监听器管理
let globalWindowListeners: (() => void)[] = [];

// 默认主窗口尺寸
const DEFAULT_MAIN_WINDOW_SIZE = { width: 1200, height: 800 };

// 设置主窗口尺寸
async function setMainWindowSize() {
  const logId = `HOME_RESIZE_${Date.now()}`;
  try {
    const currentWindow = getCurrentWebviewWindow();
    
    // 记录调整前的尺寸
    const beforeSize = await currentWindow.innerSize();
    
    // 设置为默认主窗口尺寸
    await currentWindow.setSize({
      type: 'Logical',
      width: DEFAULT_MAIN_WINDOW_SIZE.width,
      height: DEFAULT_MAIN_WINDOW_SIZE.height
    });
    
    await currentWindow.center();
    
    // 记录调整后的尺寸
    const afterSize = await currentWindow.innerSize();
  } catch (error) {
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  const logId = `HOME_PREPARE_${Date.now()}`;
  
  try {
    const currentWindow = getCurrentWebviewWindow();
    const isCurrentlyMaximized = await currentWindow.isMaximized();
    const currentSize = await currentWindow.innerSize();
    
    
    // 如果不是最大化，设置为默认主窗口尺寸
    if (!isCurrentlyMaximized) {
      await setMainWindowSize();
    } else {
    }
    
    windowStateInitialized = true;
  } catch (error) {
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
  const logId = `HOME_ACTIVATED_${Date.now()}`;
  
  // 重置状态，确保每次激活都重新设置窗口
  windowStateInitialized = false;
  
  // 立即设置窗口尺寸，避免闪烁
  prepareWindowOnLogin();
})

// 组件失活时（用于 keep-alive）
onDeactivated(() => {
  const logId = `HOME_DEACTIVATED_${Date.now()}`;
  clearAllWindowListeners();
})

// 组件挂载时
onMounted(() => {
  const logId = `HOME_MOUNTED_${Date.now()}`;
  // 立即设置窗口尺寸，避免闪烁
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
