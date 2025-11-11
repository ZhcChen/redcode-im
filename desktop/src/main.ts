import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { store } from "./store";
import "./styles/global.css";
import { invoke } from "@tauri-apps/api/core";
import toast from "./utils/toast";
import { disableNavigationShortcuts } from "./utils/keyboardShortcuts";

console.log("[Main] 应用初始化开始");

window.addEventListener("error", (event) => {
  console.error("[Main] 捕获到未处理的错误:", event.message, event.error);
});

window.addEventListener("unhandledrejection", (event) => {
  console.error("[Main] 捕获到未处理的 Promise 拒绝:", event.reason);
});

// 清理可能存在的旧登录数据，确保每次启动都是全新状态
localStorage.removeItem("authToken");
localStorage.removeItem("userInfo");

const app = createApp(App).use(router).use(store);

let fallbackTimer: number | undefined;

router.isReady().then(() => {
  console.log("[Main] 路由就绪，当前路径:", router.currentRoute.value.fullPath);
});

// 注册全局 Toast API
app.config.globalProperties.$toast = toast;

// 挂载应用前先移除预加载指示器，避免在 splashscreen 关闭后还显示
const loadingElement = document.getElementById("app-loading");
if (loadingElement) {
  loadingElement.remove();
  console.log("[Main] 预加载指示器已移除");
}

// 挂载应用
app.mount("#app");

console.log("[Main] 应用挂载完成");

// 禁用浏览器前进后退快捷键，防止用户意外触发
disableNavigationShortcuts();

fallbackTimer = window.setTimeout(async () => {
  const fallbackId = `FALLBACK_${Date.now()}`;
  console.warn(`[${fallbackId}] ========== Fallback 定时器触发 ==========`);
  console.warn(`[${fallbackId}] Fallback: 检查应用状态`);
  
  // 只在未登录且不在登录页时才执行 fallback 逻辑
  const isLoggedIn = store.getters.isLoggedIn;
  const currentPath = router.currentRoute.value.path;
  
  console.warn(`[${fallbackId}] 当前状态:`, {
    isLoggedIn,
    currentPath,
    hasToken: !!store.state.token
  });
  
  if (isLoggedIn) {
    console.log(`[${fallbackId}] Fallback: 用户已登录，跳过 fallback 处理`);
    console.warn(`[${fallbackId}] ========== Fallback 结束 (已登录) ==========`);
    return;
  }
  
  if (currentPath === '/login') {
    console.log(`[${fallbackId}] Fallback: 已在登录页，跳过 fallback 处理`);
    console.warn(`[${fallbackId}] ========== Fallback 结束 (已在登录页) ==========`);
    return;
  }
  
  console.warn(`[${fallbackId}] Fallback: 强制隐藏加载蒙版并跳转登录页`);
  console.warn(`[${fallbackId}] 调用栈:`, new Error().stack);
  try {
    store.dispatch("hideGlobalLoading");
  } catch (error) {
    console.warn(`[${fallbackId}] Fallback 隐藏蒙版失败:`, error);
  }
  const fallbackLoading = document.getElementById("app-loading");
  if (fallbackLoading) {
    fallbackLoading.remove();
  }
  if (router.currentRoute.value.name !== "Login") {
    try {
      await router.replace({ name: "Login" });
      console.log(`[${fallbackId}] Fallback 跳转至登录页`);
    } catch (error) {
      console.warn(`[${fallbackId}] Fallback 跳转登录页失败:`, error);
    }
  }
  console.warn(`[${fallbackId}] ========== Fallback 结束 (执行跳转) ==========`);
}, 5000);

// 应用挂载完成后，通知后端关闭启动画面
setTimeout(async () => {
  try {
    // 在关闭 splashscreen 之前，先确保 globalLoading 是隐藏状态
    console.log("[Main] 准备关闭启动画面，先隐藏全局加载蒙版");
    try {
      store.dispatch("hideGlobalLoading");
    } catch (error) {
      console.warn("[Main] 隐藏全局加载蒙版失败:", error);
    }

    console.log("[Main] 调用 app_ready 关闭启动画面...");
    await invoke("app_ready");
    console.log("[Main] ✅ 启动画面已关闭，主应用已显示");
  } catch (error) {
    console.error("[Main] ❌ 关闭启动画面失败:", error);
    // 如果命令调用失败，尝试直接关闭启动画面
    try {
      console.log("[Main] 尝试备用方法 close_splashscreen...");
      await invoke("close_splashscreen");
      console.log("[Main] ✅ 备用方法成功关闭启动画面");
    } catch (fallbackError) {
      console.error("[Main] ❌ 备用关闭启动画面方法也失败:", fallbackError);
    }
  }
  if (fallbackTimer) {
    clearTimeout(fallbackTimer);
    fallbackTimer = undefined;
  }
}, 800); // 减少延迟到800ms
