import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { store } from "./store";
import "./styles/global.css";
import { invoke } from "@tauri-apps/api/core";
import toast from "./utils/toast";
import { setupAutoUploadTest } from "./tests/auto-upload-test";

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

// 挂载应用
app.mount("#app");

console.log("[Main] 应用挂载完成");

// 移除预加载指示器
const loadingElement = document.getElementById("app-loading");
if (loadingElement) {
  loadingElement.remove();
}

fallbackTimer = window.setTimeout(async () => {
  console.warn("[Main] Fallback: 强制隐藏加载蒙版并跳转登录页");
  try {
    store.dispatch("hideGlobalLoading");
  } catch (error) {
    console.warn("[Main] Fallback 隐藏蒙版失败:", error);
  }
  const fallbackLoading = document.getElementById("app-loading");
  if (fallbackLoading) {
    fallbackLoading.remove();
  }
  if (router.currentRoute.value.name !== "Login") {
    try {
      await router.replace({ name: "Login" });
      console.log("[Main] Fallback 跳转至登录页");
    } catch (error) {
      console.warn("[Main] Fallback 跳转登录页失败:", error);
    }
  }
}, 5000);

// 应用挂载完成后，通知后端关闭启动画面
setTimeout(async () => {
  try {
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

// 自动化头像上传测试（仅当同时开启两个开关时自动执行）
const shouldEnableAutoUploadTest = import.meta.env.VITE_AUTO_UPLOAD_TEST === 'true';
const shouldAutoStartUploadTest = import.meta.env.VITE_AUTO_UPLOAD_AUTOSTART === 'true';

if (shouldEnableAutoUploadTest) {
  if (import.meta.env.DEV) {
    (window as typeof window & { __runAutoUploadTest?: () => void }).__runAutoUploadTest = setupAutoUploadTest;
    console.info('[AutoUploadTest] 已在开发者工具中暴露 window.__runAutoUploadTest() 手动触发。');
  }
  if (shouldAutoStartUploadTest) {
    setupAutoUploadTest();
  } else {
    console.info('[AutoUploadTest] 自动执行已关闭，可在控制台调用 window.__runAutoUploadTest() 手动运行。');
  }
}
