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
import { onMounted, onUnmounted } from 'vue'
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

// 智能调整窗口尺寸，确保不超出屏幕
async function smartAdjustWindowSize() {
  try {
    const currentWindow = getCurrentWebviewWindow();
    const currentSize = await currentWindow.innerSize();

    // 检查 API 可用性
    if (typeof currentWindow.primaryMonitor !== 'function') {
      console.warn('primaryMonitor API 不可用，跳过智能窗口调整');
      return;
    }

    const monitor = await currentWindow.primaryMonitor();

    if (!monitor) return;

    // 获取屏幕物理尺寸
    const screenWidth = monitor.size.width;
    const screenHeight = monitor.size.height;

    // 计算更保守的安全区域，考虑任务栏、标题栏等系统组件
    // Windows任务栏通常占用40-48像素高度，加上窗口标题栏约30像素
    const systemReservedHeight = 100; // 预留系统组件高度
    const systemReservedWidth = 20;   // 预留左右边距

    // 计算安全的可用区域
    const availableWidth = screenWidth - systemReservedWidth;
    const availableHeight = screenHeight - systemReservedHeight;

    // 计算合适的窗口尺寸（可用区域的75%，确保足够的边距）
    const maxSafeWidth = Math.min(availableWidth * 0.75, 1400);
    const maxSafeHeight = Math.min(availableHeight * 0.75, 800); // 降低最大高度

    // 检查当前窗口是否超出安全范围
    if (currentSize.width > maxSafeWidth || currentSize.height > maxSafeHeight) {
      const newWidth = Math.min(currentSize.width, maxSafeWidth);
      const newHeight = Math.min(currentSize.height, maxSafeHeight);

      await currentWindow.setSize({
        type: 'Logical',
        width: newWidth,
        height: newHeight
      });

      // 重新居中窗口
      await currentWindow.center();

      console.log(`窗口尺寸已调整为安全范围: ${newWidth}x${newHeight}`);
      console.log(`屏幕尺寸: ${screenWidth}x${screenHeight}, 可用区域: ${availableWidth}x${availableHeight}`);
    }
  } catch (error) {
    console.error("智能调整窗口尺寸失败:", error);
  }
}

// 登录后窗口尺寸调整逻辑
async function prepareWindowOnLogin() {
  try {
    const currentWindow = getCurrentWebviewWindow();

    const isCurrentlyMaximized = await currentWindow.isMaximized();
    originalMaximized = isCurrentlyMaximized;

    if (!originalMaximized) {
      const currentSize = await currentWindow.innerSize();
      originalSize = {
        width: currentSize.width,
        height: currentSize.height,
      };
    }

    // 只在窗口尺寸超过安全范围时收缩
    await smartAdjustWindowSize();

    windowStateInitialized = true;
  } catch (error) {
    console.error("准备窗口尺寸失败:", error);
    windowStateInitialized = true;
  }
}

// 恢复窗口状态
async function restoreWindow() {
  try {
    if (!windowStateInitialized || originalMaximized) {
      return;
    }
    
    if (originalSize) {
      const currentWindow = getCurrentWebviewWindow();
      
      // 检查当前是否为最大化状态
      const isCurrentlyMaximized = await currentWindow.isMaximized();
      
      if (isCurrentlyMaximized) {
        // 取消最大化
        await currentWindow.unmaximize();
      }
      
      // 恢复到原始大小
      await currentWindow.setSize({ 
        type: 'Logical', 
        width: originalSize.width, 
        height: originalSize.height 
      });
      
      console.log("主页窗口状态已恢复");
    }
  } catch (error) {
    console.error("恢复窗口状态失败:", error);
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

// 安全的监听器创建
async function createSafeWindowListener(event: string, handler: () => void) {
  const currentWindow = getCurrentWebviewWindow();
  const unlisten = await currentWindow.listen(event, handler);
  globalWindowListeners.push(unlisten);
  return unlisten;
}

// 设置窗口监听
async function setupWindowListeners() {
  try {
    // 先清理旧的监听器
    clearAllWindowListeners();
    
    const currentWindow = getCurrentWebviewWindow();
    
    // 监听窗口调整大小事件
    resizeUnlisten = await createSafeWindowListener('tauri://resize', async () => {
      // 延迟执行，确保窗口状态稳定
      setTimeout(async () => {
        const isMaximized = await currentWindow.isMaximized();
        // 如果窗口不是最大化状态，检查并调整尺寸
        if (!isMaximized) {
          await smartAdjustWindowSize();
        }
      }, 100);
    });
    
    console.log("窗口监听器已设置，当前监听器数量:", globalWindowListeners.length);
  } catch (error) {
    console.error("设置窗口监听器失败:", error);
  }
}

// 组件挂载时自动最大化窗口并设置监听
onMounted(() => {
  setTimeout(async () => {
    await prepareWindowOnLogin();
    await setupWindowListeners();
  }, 200);
});

// 组件卸载时恢复窗口状态并清理监听器
onUnmounted(() => {
  // 清理所有窗口监听器
  clearAllWindowListeners();
  
  restoreWindow();
});
</script>

<style lang="scss" scoped>
.home {
  width: 100%;
  height: 100vh;
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
