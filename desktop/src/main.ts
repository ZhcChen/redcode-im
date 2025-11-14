import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { store } from "./store";
import "./styles/global.css";
import { invoke } from "@tauri-apps/api/core";
import toast from "./utils/toast";
import { disableNavigationShortcuts } from "./utils/keyboardShortcuts";


window.addEventListener("error", (event) => {
});

window.addEventListener("unhandledrejection", (event) => {
});

// 清理可能存在的旧登录数据，确保每次启动都是全新状态
localStorage.removeItem("authToken");
localStorage.removeItem("userInfo");

const app = createApp(App).use(router).use(store);

let fallbackTimer: number | undefined;

router.isReady().then(() => {
});

// 注册全局 Toast API
app.config.globalProperties.$toast = toast;

// 挂载应用前先移除预加载指示器，避免在 splashscreen 关闭后还显示
const loadingElement = document.getElementById("app-loading");
if (loadingElement) {
  loadingElement.remove();
}

// 挂载应用
app.mount("#app");


// 禁用浏览器前进后退快捷键，防止用户意外触发
disableNavigationShortcuts();

fallbackTimer = window.setTimeout(async () => {
  const fallbackId = `FALLBACK_${Date.now()}`;
  
  // 只在未登录且不在登录页时才执行 fallback 逻辑
  const isLoggedIn = store.getters.isLoggedIn;
  const currentPath = router.currentRoute.value.path;
  
  
  if (isLoggedIn) {
    return;
  }
  
  if (currentPath === '/login') {
    return;
  }
  
  try {
    store.dispatch("hideGlobalLoading");
  } catch (error) {
  }
  const fallbackLoading = document.getElementById("app-loading");
  if (fallbackLoading) {
    fallbackLoading.remove();
  }
  if (router.currentRoute.value.name !== "Login") {
    try {
      await router.replace({ name: "Login" });
    } catch (error) {
    }
  }
}, 5000);

// 应用挂载完成后，通知后端关闭启动画面
setTimeout(async () => {
  try {
    // 在关闭 splashscreen 之前，先确保 globalLoading 是隐藏状态
    try {
      store.dispatch("hideGlobalLoading");
    } catch (error) {
    }

    await invoke("app_ready");
  } catch (error) {
    // 如果命令调用失败，尝试直接关闭启动画面
    try {
      await invoke("close_splashscreen");
    } catch (fallbackError) {
    }
  }
  if (fallbackTimer) {
    clearTimeout(fallbackTimer);
    fallbackTimer = undefined;
  }
}, 800); // 减少延迟到800ms
