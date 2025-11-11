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
    console.log(`[${logId}] ========== 设置主窗口尺寸 ==========`);
    console.log(`[${logId}] 调整前尺寸: ${beforeSize.width}x${beforeSize.height}`);
    console.log(`[${logId}] 目标尺寸: ${DEFAULT_MAIN_WINDOW_SIZE.width}x${DEFAULT_MAIN_WINDOW_SIZE.height}`);
    console.log(`[${logId}] 调用栈:`, new Error().stack);
    
    // 设置为默认主窗口尺寸
    await currentWindow.setSize({
      type: 'Logical',
      width: DEFAULT_MAIN_WINDOW_SIZE.width,
      height: DEFAULT_MAIN_WINDOW_SIZE.height
    });
    
    await currentWindow.center();
    
    // 记录调整后的尺寸
    const afterSize = await currentWindow.innerSize();
    console.log(`[${logId}] 调整后尺寸: ${afterSize.width}x${afterSize.height}`);
    console.log(`[${logId}] ========== 设置完成 ==========`);
  } catch (error) {
    console.error(`[${logId}] 设置主窗口尺寸失败:`, error);
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  const logId = `HOME_PREPARE_${Date.now()}`;
  console.log(`[${logId}] ========== 准备主窗口 ==========`);
  console.log(`[${logId}] windowStateInitialized: ${windowStateInitialized}`);
  
  try {
    const currentWindow = getCurrentWebviewWindow();
    const isCurrentlyMaximized = await currentWindow.isMaximized();
    const currentSize = await currentWindow.innerSize();
    
    console.log(`[${logId}] 当前状态:`, {
      isMaximized: isCurrentlyMaximized,
      currentSize: `${currentSize.width}x${currentSize.height}`
    });
    
    // 如果不是最大化，设置为默认主窗口尺寸
    if (!isCurrentlyMaximized) {
      await setMainWindowSize();
    } else {
      console.log(`[${logId}] 窗口已最大化，跳过尺寸设置`);
    }
    
    windowStateInitialized = true;
    console.log(`[${logId}] ========== 准备完成 ==========`);
  } catch (error) {
    console.error(`[${logId}] 准备窗口尺寸失败:`, error);
    windowStateInitialized = true;
  }
}

// 清理所有窗口监听器
function clearAllWindowListeners() {
  console.log('🧹 清理所有窗口监听器，当前数量:', globalWindowListeners.length);
  globalWindowListeners.forEach(unlisten => {
    try {
      unlisten();
    } catch (error) {
      console.warn('清理窗口监听器失败:', error);
    }
  });
  globalWindowListeners = [];
  
  // 清理旧的resize监听器
  if (resizeUnlisten) {
    try {
      resizeUnlisten();
    } catch (error) {
      console.warn('清理resize监听器失败:', error);
    }
    resizeUnlisten = null;
  }
}

// 组件激活时（用于 keep-alive）
onActivated(() => {
  const logId = `HOME_ACTIVATED_${Date.now()}`;
  console.log(`[${logId}] ========== Home 组件激活 ==========`);
  console.log(`[${logId}] 重置 windowStateInitialized`);
  
  // 重置状态，确保每次激活都重新设置窗口
  windowStateInitialized = false;
  
  // 立即设置窗口尺寸，避免闪烁
  prepareWindowOnLogin();
})

// 组件失活时（用于 keep-alive）
onDeactivated(() => {
  const logId = `HOME_DEACTIVATED_${Date.now()}`;
  console.log(`[${logId}] ========== Home 组件失活 ==========`);
  clearAllWindowListeners();
})

// 组件挂载时
onMounted(() => {
  const logId = `HOME_MOUNTED_${Date.now()}`;
  console.log(`[${logId}] ========== Home 组件挂载 ==========`);
  // 立即设置窗口尺寸，避免闪烁
  prepareWindowOnLogin();
});

// 组件卸载时
onUnmounted(() => {
  const logId = `HOME_UNMOUNTED_${Date.now()}`;
  console.log(`[${logId}] ========== Home 组件卸载 ==========`);
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
