import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { store } from "./store";
import "./styles/global.css";
import { invoke } from '@tauri-apps/api/core';
import toast from './utils/toast';

// 清理可能存在的旧登录数据，确保每次启动都是全新状态
localStorage.removeItem('authToken');
localStorage.removeItem('userInfo');

const app = createApp(App).use(router).use(store);

// 注册全局 Toast API
app.config.globalProperties.$toast = toast;

// 挂载应用
app.mount("#app");

// 移除预加载指示器
const loadingElement = document.getElementById('app-loading');
if (loadingElement) {
  loadingElement.remove();
}

// 应用挂载完成后，通知后端关闭启动画面
setTimeout(async () => {
  try {
    console.log('[Main] 调用 app_ready 关闭启动画面...');
    await invoke('app_ready');
    console.log('[Main] ✅ 启动画面已关闭，主应用已显示');
  } catch (error) {
    console.error('[Main] ❌ 关闭启动画面失败:', error);
    // 如果命令调用失败，尝试直接关闭启动画面
    try {
      console.log('[Main] 尝试备用方法 close_splashscreen...');
      await invoke('close_splashscreen');
      console.log('[Main] ✅ 备用方法成功关闭启动画面');
    } catch (fallbackError) {
      console.error('[Main] ❌ 备用关闭启动画面方法也失败:', fallbackError);
    }
  }
}, 800); // 减少延迟到800ms
