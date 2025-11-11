<template>
  <div class="login-container" :class="{ 'login-container--modal': isModalMode }">
    <div class="login-container-header">
      <div class="login-container-header-left">
        <div class="login-container-header-left-title">Hello!</div>
        <div class="login-container-header-left-subtitle">欢迎来到CHATLY</div>
      </div>
      <div class="login-container-header-right">
        <img
          class="login-container-header-right-img"
          src="@/assets/image/logo-text.svg"
          alt=""
        />
      </div>
    </div>
    <div class="login-container-form">
      <BTabs
        v-model="loginType"
        :tabs="loginTabs"
        @change="handleLoginTypeChange"
      />
      <div class="login-container-form-item">
        <div class="login-container-form-item-label">
          {{ primaryFieldLabel }}
        </div>
        <div class="login-container-form-item-value">
          <b-input
            v-model="loginForm.phone"
            :placeholder="primaryFieldPlaceholder"
            @keydown="handleKeydown"
          ></b-input>
        </div>
      </div>
      <div class="login-container-form-item" v-if="loginType === 'password'">
        <div class="login-container-form-item-label">密码</div>
        <div class="login-container-form-item-value">
          <b-input
            v-model="loginForm.password"
            type="password"
            placeholder="请输入密码"
            @keydown="handleKeydown"
          ></b-input>
        </div>
      </div>
      <div class="login-container-form-item" v-if="loginType === 'captcha'">
        <div class="login-container-form-item-label">验证码</div>
        <div
          class="login-container-form-item-value login-container-form-item-value-captcha"
        >
          <div class="login-container-form-item-captcha-input">
            <b-input
              v-model="loginForm.captcha"
              placeholder="请输入验证码"
              @keydown="handleKeydown"
            ></b-input>
          </div>
          <b-button
            @click="handleSendCaptcha"
            :disabled="isSendingCaptcha || countdown > 0"
            class="login-container-form-item-captcha-button"
          >
            {{
              countdown > 0
                ? `${countdown}s后重发`
                : isSendingCaptcha
                  ? "发送中..."
                  : "发送验证码"
            }}
          </b-button>
        </div>
      </div>
      <div class="login-container-form-item">
        <b-button @click="handleLogin" :disabled="isLoading">
          {{ isLoading ? "登录中..." : "登录账号" }}
        </b-button>
      </div>
      <div class="login-container-form-agree">
        <b-radio v-model="isAgreed"></b-radio>
        <div class="login-container-form-agree-text">
          注册/登陆即代表同意《用户协议》和《隐私协议》
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { LogicalSize } from "@tauri-apps/api/dpi";
import { invoke } from "@tauri-apps/api/core";
import BInput from "@/components/BInput.vue";
import BButton from "@/components/BButton.vue";
import BRadio from "@/components/BRadio.vue";
import BTabs from "@/components/BTabs.vue";
import { useStore } from "vuex";
import { SystemApi } from "@/api";
import toast from "@/utils/toast";

const props = withDefaults(
  defineProps<{
    /**
     * page: 作为独立页面使用，包含窗口尺寸管理
     * modal: 作为弹窗内容使用，不修改主窗口尺寸
     */
    mode?: "page" | "modal";
  }>(),
  {
    mode: "page",
  },
);

const emit = defineEmits<{
  (e: "login-success", payload: { accountId: string; nickname: string }): void;
}>();

const router = useRouter();
const store = useStore();

const isModalMode = computed(() => props.mode === "modal");
const DEFAULT_MAIN_WINDOW_SIZE = Object.freeze({ width: 1000, height: 650 });

let loginWindowTimer: number | null = null;

const isAgreed = ref(true);

// 登录类型选项
const loginTabs = [
  { label: "密码登录", value: "password" },
  { label: "验证码登录", value: "captcha" },
];

// 窗口大小管理
let originalSize: { width: number; height: number } | null = null;
let originalResizable: boolean = true;

// 设置登录页面窗口大小
async function setLoginWindowSize() {
  const logId = `LOGIN_RESIZE_${Date.now()}`;
  console.log(`[${logId}] ========== 设置登录窗口尺寸 ==========`);
  
  if (isModalMode.value) {
    console.log(`[${logId}] 模态模式，跳过窗口尺寸设置`);
    return;
  }

  if (store.getters.isLoggedIn) {
    console.log(`[${logId}] 检测到已有登录态，跳过窗口尺寸调整`);
    return;
  }

  try {
    const currentWindow = getCurrentWebviewWindow();

    // 保存原始窗口大小和可调整状态
    const currentSize = await currentWindow.innerSize();
    console.log(`[${logId}] 调整前尺寸: ${currentSize.width}x${currentSize.height}`);
    console.log(`[${logId}] 保存原始尺寸: ${currentSize.width}x${currentSize.height}`);
    
    originalSize = {
      width: currentSize.width,
      height: currentSize.height,
    };
    originalResizable = await currentWindow.isResizable();

    // 设置窗口标题
    await currentWindow.setTitle("Chatly");

    // 禁止调整窗口大小
    try {
      await currentWindow.setResizable(false);
    } catch (error) {
      console.warn(`[${logId}] 设置窗口可调整状态失败:`, error);
    }

    console.log(`[${logId}] 目标尺寸: 400x600`);
    console.log(`[${logId}] 调用栈:`, new Error().stack);
    
    // 使用 Rust 后端设置窗口大小并居中
    await invoke("set_window_size_and_center", { width: 400, height: 600 });

    const afterSize = await currentWindow.innerSize();
    console.log(`[${logId}] 调整后尺寸: ${afterSize.width}x${afterSize.height}`);
    console.log(`[${logId}] ========== 设置完成 ==========`);
  } catch (error) {
    console.error(`[${logId}] 设置登录页面窗口大小失败:`, error);
    // 回退到前端方法
    try {
      const currentWindow = getCurrentWebviewWindow();
      await currentWindow.setSize(new LogicalSize(400, 600));
      await currentWindow.center();
      console.log(`[${logId}] 使用前端方法设置成功`);
    } catch (fallbackError) {
      console.error(`[${logId}] 回退方法也失败:`, fallbackError);
    }
  }
}

// 恢复原始窗口大小和可调整状态
async function restoreOriginalWindowSize() {
  if (isModalMode.value) {
    return;
  }

  try {
    const currentWindow = getCurrentWebviewWindow();

    // 恢复窗口可调整状态（若未记录则回退为可调整）
    try {
      await currentWindow.setResizable(originalResizable);
    } catch (error) {
      console.warn('恢复窗口可调整状态失败:', error);
    }

    const sizeToRestore = originalSize ?? DEFAULT_MAIN_WINDOW_SIZE;

    if (!originalSize) {
      console.warn(
        `[Login] 未捕获原始窗口尺寸，使用默认主窗口 ${sizeToRestore.width}x${sizeToRestore.height} 恢复`,
      );
    }

    await invoke("set_window_size_and_center", {
      width: sizeToRestore.width,
      height: sizeToRestore.height,
    });

    console.log(
      "窗口大小和可调整状态已通过 Rust 后端恢复为原始设置（保持标题不变）",
    );
  } catch (error) {
    console.error("恢复窗口大小失败:", error);
    // 回退到前端方法
    const fallbackSize = originalSize ?? DEFAULT_MAIN_WINDOW_SIZE;
    try {
      const currentWindow = getCurrentWebviewWindow();
      await currentWindow.setSize(
        new LogicalSize(fallbackSize.width, fallbackSize.height),
      );
      await currentWindow.center();
    } catch (fallbackError) {
      console.error("回退方法也失败:", fallbackError);
    }
  }
}

// 组件挂载时设置窗口大小
onMounted(() => {
  console.log("[Login] 页面已挂载，准备隐藏全局加载蒙版");
  try {
    store.dispatch("hideGlobalLoading");
  } catch (error) {
    console.warn("[Login] 隐藏全局加载蒙版失败:", error);
  }

  // 添加短暂延迟确保路由跳转完成
  if (!isModalMode.value) {
    loginWindowTimer = window.setTimeout(() => {
      loginWindowTimer = null;
      void setLoginWindowSize();
    }, 120);
  }
});

// 处理登录
async function handleLogin() {
  console.log("[Login] handleLogin invoked");
  // 表单验证
  if (!validateForm()) {
    console.warn("[Login] 表单验证未通过, 阻止登录");
    return;
  }

  isLoading.value = true;
  console.log("[Login] isLoading -> true");

  try {
    // 在开始登录前立即重置登出状态，确保可以发起API请求
    const { setLoggingOut, setLoginTime, clearLoginTime } = await import(
      "@/api/http"
    );
    console.log("[Login] 已加载 http 模块, 重置登出状态");
    setLoggingOut(false);
    clearLoginTime(); // 清除之前的登录时间
    console.log("📝 已重置登出状态和登录时间，开始登录流程");

    let response;

    if (loginType.value === "password") {
      // 密码登录
      console.log("[Login] 发起密码登录请求");
      response = await SystemApi.login({
        mobile: loginForm.value.phone,
        password: loginForm.value.password,
        userDeviceId: Date.now(),
      });
    } else {
      // 验证码登录
      console.log("[Login] 发起验证码登录请求");
      response = await SystemApi.loginWithSMS({
        phone: loginForm.value.phone,
        code: loginForm.value.captcha,
      });
    }

    if (response.success && response.data) {
      // 登录成功，立即设置登录时间（在状态更新之前）
      setLoginTime();
      console.log("⏰ 已设置登录时间戳");

      // 登录成功，保存用户信息和token到store
      // 将API返回的数据格式映射为Store期望的格式
      const userInfo = response.data.userInfo;
      const mappedUserInfo = {
        id: String(userInfo.id),
        username: userInfo.username,
        nickname: userInfo.nickname || userInfo.username,
        avatar: userInfo.avatar || "",
        avatarObjectKey: userInfo.avatarObjectKey ?? null,
        avatarLocalPath: userInfo.avatarLocalPath ?? null,
        mobile: userInfo.mobile || userInfo.username,
        email: userInfo.email || "",
        realName: userInfo.realName || userInfo.nickname || userInfo.username,
        chatNumber: userInfo.chatNumber || userInfo.username,
        address: userInfo.address || "",
        createTime: userInfo.createTime || null,
        lastLoginTime: userInfo.lastLoginTime || null,
        activeStatus: userInfo.activeStatus ?? null,
        delFlag: userInfo.delFlag ?? null,
        level: userInfo.level ?? null,
        userDeviceId: userInfo.userDeviceId || null,
        userSign: userInfo.userSign || null,
        trcSdkAppId: userInfo.trcSdkAppId ?? null,
        powerList: userInfo.powerList ?? null,
      };

      console.log("📸 登录响应中的头像信息:", {
        originalAvatar: userInfo.avatar,
        mappedAvatar: mappedUserInfo.avatar,
        fullUserInfo: userInfo,
      });

      await store.dispatch("login", {
        token: response.data.token,
        userInfo: mappedUserInfo,
      });
      console.log("[Login] 首次 dispatch login 完成");

      // 将账号添加到 accounts 模块（支持多账号）
      try {
        const accountInfo = {
          id: mappedUserInfo.id,
          token: response.data.token,
          userInfo: mappedUserInfo,
          unreadCount: 0,
          createdAt: Date.now()
        };

        // 检查账号是否已存在
        const existingAccount = store.getters['accounts/getAccountById'](mappedUserInfo.id);
        if (existingAccount) {
          // 更新现有账号信息
          await store.commit('accounts/UPDATE_ACCOUNT', {
            accountId: mappedUserInfo.id,
            data: accountInfo
          });
          console.log('✅ 账号已存在，已更新账号信息');
        } else {
          // 添加新账号
          await store.dispatch('accounts/addAccount', accountInfo);
          console.log('✅ 新账号已添加到 accounts 模块');
        }

        // 设置为当前账号
        await store.dispatch('accounts/switchAccount', mappedUserInfo.id);
        console.log('✅ 已切换到当前账号');
      } catch (accountError) {
        console.error('❌ 添加账号到 accounts 模块失败:', accountError);
        // 不阻断登录流程，只记录错误
      }

      console.log("登录成功:", response.data);

      // 等待更长时间确保状态完全同步，避免竞态条件
      await new Promise((resolve) => setTimeout(resolve, 800)); // 增加延迟

      // 验证token是否正确设置到store中
      const verifyToken = store.state.token;
      const verifyLoggedIn = store.getters.isLoggedIn;
      console.log("🔍 登录完成后状态验证:", {
        storeTokenSet: !!verifyToken,
        storeTokenPreview: verifyToken
          ? `${verifyToken.substring(0, 10)}...`
          : "无token",
        isLoggedIn: verifyLoggedIn,
        tokenMatch: verifyToken === response.data.token,
        userInfo: mappedUserInfo,
        currentTime: new Date().toISOString(),
      });

      // 如果token验证失败，重新设置
      if (!verifyToken || verifyToken !== response.data.token) {
        console.warn("⚠️ Token验证失败，重新设置...");
        await store.dispatch("login", {
          token: response.data.token,
          userInfo: mappedUserInfo,
        });
        // 再次等待确保设置完成
        await new Promise((resolve) => setTimeout(resolve, 500));
        console.log("[Login] 第二次 dispatch login 完成");
      }

      // 更新窗口标题
      try {
        console.log("🔄 准备更新窗口标题，用户信息:", mappedUserInfo);
        const { updateWindowTitle } = await import("@/utils");
        await updateWindowTitle(mappedUserInfo);
        console.log("✅ 窗口标题更新完成");
      } catch (error) {
        console.error("❌ 更新窗口标题失败:", error);
      }

      // 同步头像缓存
      try {
        console.log("🔄 [Login] 准备同步头像缓存...");
        const { UserApi } = await import("@/api");
        await UserApi.syncAvatarCache(true);
        console.log("✅ [Login] 头像缓存同步完成");
      } catch (avatarError) {
        console.error("❌ [Login] 同步头像缓存失败:", avatarError);
      }

      // 最后等待确保所有异步操作完成
      await new Promise((resolve) => setTimeout(resolve, 200));

      // 登录成功跳转前的最终状态确认
      const finalToken = store.state.token;
      const finalLoggedIn = store.getters.isLoggedIn;
      console.log("🏁 登录流程最终状态确认:", {
        hasToken: !!finalToken,
        isLoggedIn: finalLoggedIn,
        readyToNavigate: !!(finalToken && finalLoggedIn),
        currentPath: window.location.pathname,
        targetPath: "/home",
      });

      // 只有在状态确认无误时才跳转
      if (finalToken && finalLoggedIn) {
        console.log("✅ 状态验证通过，开始页面跳转...");

        const successPayload = {
          accountId: mappedUserInfo.id,
          nickname: mappedUserInfo.nickname,
        };

        if (isModalMode.value) {
          emit("login-success", successPayload);
          return;
        }

        // 检查是否在独立的登录窗口中（通过窗口label判断）
        try {
          const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
          const currentWindow = getCurrentWebviewWindow();
          const windowLabel = currentWindow.label;

          console.log('当前窗口label:', windowLabel);

          // 如果是独立的登录窗口（label以'login-'开头）
          if (windowLabel.startsWith('login-')) {
            console.log('✅ 在独立登录窗口中，账号已添加，关闭窗口');

            // 通知主窗口刷新账号列表
            try {
              const { emit } = await import('@tauri-apps/api/event');
              await emit('account-added', {
                accountId: mappedUserInfo.id,
                nickname: mappedUserInfo.nickname
              });
              console.log('✅ 已通知主窗口刷新账号列表');
            } catch (error) {
              console.warn('通知主窗口失败:', error);
            }

            // 延迟关闭窗口，让用户看到成功提示
            await new Promise(resolve => setTimeout(resolve, 500));
            await currentWindow.close();
            return;
          }
        } catch (error) {
          console.warn('检查窗口类型失败:', error);
        }

        // 主窗口登录，跳转到首页
        router.replace({ name: "Home" });
      } else {
        console.error("❌ 登录状态验证失败，无法跳转");
        toast.error("登录状态异常，请重试");
      }
    } else {
      // 登录失败
      toast.error(response.message || "登录失败，请检查账号密码");
      console.error("登录失败:", response.message || "未知错误");
    }
  } catch (error: any) {
    console.error("登录请求失败:", error);
    toast.error(error.message || "网络错误，请稍后重试");
  } finally {
    console.log("[Login] handleLogin finally, isLoading -> false");
    isLoading.value = false;
  }
}

// 组件卸载时清理定时器
onUnmounted(() => {
  if (countdownTimer) {
    clearInterval(countdownTimer);
    countdownTimer = null;
  }
  if (loginWindowTimer !== null) {
    clearTimeout(loginWindowTimer);
    loginWindowTimer = null;
  }
  restoreOriginalWindowSize();
});

// 表单数据 - 默认填入账号信息
const DEFAULT_CAPTCHA = "666666";

// 默认填入测试账号，便于本地开发调试
const loginForm = ref({
  phone: "alice",
  password: "a123456",
  captcha: DEFAULT_CAPTCHA,
});

// 登录类型：password 密码登录 | captcha 验证码登录
const loginType = ref<"password" | "captcha">("password");

// 表单状态
const showPassword = ref(false);
const agreedToTerms = ref(false);
const isLoading = ref(false);
const isSendingCaptcha = ref(false);
const countdown = ref(0);
let countdownTimer: NodeJS.Timeout | null = null;

// 表单验证
const primaryFieldLabel = computed(() =>
  loginType.value === "captcha" ? "账号" : "账号 / 手机号",
);
const primaryFieldPlaceholder = computed(() =>
  loginType.value === "captcha" ? "请输入账号" : "请输入账号或手机号",
);

const isFormValid = computed(() => {
  const account = loginForm.value.phone.trim();
  if (loginType.value === "password") {
    return (
      account.length > 0 &&
      loginForm.value.password.length >= 6 &&
      isAgreed.value
    );
  }
  return (
    account.length > 0 && loginForm.value.captcha.length === 6 && isAgreed.value
  );
});

// 切换登录类型
function handleLoginTypeChange(value: string | number) {
  // 切换登录类型时重置相关输入值
  if (value === "password") {
    loginForm.value.captcha = DEFAULT_CAPTCHA;
  } else {
    loginForm.value.password = "";
    loginForm.value.captcha = DEFAULT_CAPTCHA;
  }
}

// 表单验证函数
function validateForm(): boolean {
  const account = loginForm.value.phone.trim();
  const isCaptchaMode = loginType.value === "captcha";

  if (!account) {
    toast.error(isCaptchaMode ? "请输入账号" : "请输入手机号");
    return false;
  }

  if (!isCaptchaMode) {
    const phoneValue = loginForm.value.phone;
    const isAllDigits = /^\d+$/.test(phoneValue);
    if (isAllDigits && phoneValue.length !== 11) {
      toast.error("请输入正确的手机号");
      return false;
    }
  }

  if (loginType.value === "password") {
    if (!loginForm.value.password.trim()) {
      toast.error("请输入密码");
      return false;
    }

    if (loginForm.value.password.length < 6) {
      toast.error("密码长度至少为6位");
      return false;
    }
  } else {
    if (!loginForm.value.captcha.trim()) {
      toast.error("请输入验证码");
      return false;
    }

    if (loginForm.value.captcha.length !== 6) {
      toast.error("验证码长度为6位");
      return false;
    }
  }

  if (!isAgreed.value) {
    toast.error("请先同意用户协议和隐私协议");
    return false;
  }

  return true;
}

// 发送验证码
async function handleSendCaptcha() {
  if (!loginForm.value.phone.trim()) {
    toast.error("请输入账号");
    return;
  }

  isSendingCaptcha.value = true;

  try {
    const response = await SystemApi.sendLoginSMS({
      phone: loginForm.value.phone,
    });

    if (response.success) {
      toast.success("验证码已发送");
      // 开始倒计时
      countdown.value = 60;
      if (countdownTimer) {
        clearInterval(countdownTimer);
      }
      countdownTimer = setInterval(() => {
        countdown.value--;
        if (countdown.value <= 0) {
          if (countdownTimer) {
            clearInterval(countdownTimer);
            countdownTimer = null;
          }
        }
      }, 1000);
    } else {
      toast.error(response.message || "发送验证码失败");
    }
  } catch (error: any) {
    console.error("发送验证码失败:", error);
    toast.error(error.message || "网络错误，请稍后重试");
  } finally {
    isSendingCaptcha.value = false;
  }
}

// 处理键盘事件（回车登录）
function handleKeydown(event: KeyboardEvent) {
  if (event.key === "Enter") {
    event.preventDefault();
    handleLogin();
  }
}
</script>

<style scoped lang="scss">
.login-container {
  height: 100vh;
  width: 100vw;
  overflow: hidden;
  background: url("@/assets/image/login-bg.svg");
  display: flex;
  flex-direction: column;

  &-header {
    padding: 52px 32px 0 32px;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;

    &-left {
      &-title {
        font-size: 32px;
        font-weight: bold;
      }

      &-subtitle {
        font-size: 16px;
        margin-top: 8px;
      }
    }

    &-right {
      img {
        width: 115px;
        height: 24px;
        margin-bottom: -4px;
      }
    }
  }

  &-form {
    background: var(--bg-color);
    border-radius: 16px 16px 0 0;
    margin: 40px 24px 0 24px;
    box-sizing: border-box;
    padding: 16px 36px 0 36px;
    flex: 1;

    &-item {
      &-label {
        padding-left: 12px;
        font-size: 14px;
        line-height: 18px;
      }

      &-value {
        margin-top: 12px;

        &-captcha {
          display: flex;
          align-items: center;
          gap: 12px;
          width: 100%;
        }
      }

      &-captcha-input {
        flex: 1;
        min-width: 0;

        :deep(.b-input) {
          width: 100%;
        }
      }

      &-captcha-button {
        flex-shrink: 0;
        min-width: 90px;
        width: auto;

        :deep(.b-button) {
          width: 100%;
        }
      }

      &:not(:last-child) {
        margin-bottom: 24px;
      }
    }

    &-agree {
      margin-top: 17px;
      @include flex-center-vertical;

      &-text {
        color: var(--text-secondary);
        font-size: 11px;
        margin-left: 6px;
      }
    }
  }
}

.login-container--modal {
  width: 100%;
  max-width: 440px;
  height: auto;
  max-height: 85vh;
  overflow: auto;
  background: transparent;
  padding: 0;
  margin: 0 auto;

  .login-container-header {
    padding: 16px 0 8px;
  }

  .login-container-form {
    margin: 0;
    padding: 24px;
    border-radius: 16px;
    box-shadow: 0 12px 30px rgba(15, 23, 42, 0.12);
    background: #fff;
  }
}
</style>
