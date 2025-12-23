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
      <div class="login-container-form-item" v-if="loginType === 'password' || loginType === 'register'">
        <div class="login-container-form-item-label">{{ loginType === 'register' ? '设置密码' : '密码' }}</div>
        <div class="login-container-form-item-value">
          <b-input
            v-model="loginForm.password"
            type="password"
            :placeholder="loginType === 'register' ? '请设置您的登录密码' : '请输入密码'"
            @keydown="handleKeydown"
          ></b-input>
        </div>
      </div>
      <div class="login-container-form-item" v-if="loginType === 'captcha' || (loginType === 'password' && requireCaptchaForLogin) || (loginType === 'register' && requireCaptchaForLogin)">
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
        <b-button @click="handleSubmit" :disabled="isLoading">
          {{ isLoading ? (loginType === 'register' ? "注册中..." : "登录中...") : (loginType === 'register' ? "注册账号" : "登录账号") }}
        </b-button>
      </div>
      <div class="login-container-form-switch" v-if="loginType !== 'register'">
        <span class="login-container-form-switch-text">新用户？</span>
        <span class="login-container-form-switch-link" @click="switchToRegister">立即注册</span>
      </div>
      <div class="login-container-form-switch" v-if="loginType === 'register'">
        <span class="login-container-form-switch-text">已有账号？</span>
        <span class="login-container-form-switch-link" @click="switchToLogin">立即登录</span>
      </div>
      <div class="login-container-form-agree">
        <b-radio v-model="isAgreed"></b-radio>
        <div class="login-container-form-agree-text">
          注册/登陆即代表同意
          <span class="agreement-link" @click="showUserAgreement">《用户协议》</span>
          和
          <span class="agreement-link" @click="showPrivacyAgreement">《隐私协议》</span>
        </div>
      </div>
    </div>
    
    <!-- 协议对话框 -->
    <AgreementDialog
      v-model:visible="showAgreementDialog"
      :title="agreementDialogTitle"
      :htmlContent="agreementDialogContent"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { invoke } from "@tauri-apps/api/core";
import { setWindowSizeSafe, installUserResizeListener, resetUserResizedFlag } from "@/utils/window";
import BInput from "@/components/BInput.vue";
import BButton from "@/components/BButton.vue";
import BRadio from "@/components/BRadio.vue";
import BTabs from "@/components/BTabs.vue";
import AgreementDialog from "@/components/AgreementDialog.vue";
import { useStore } from "vuex";
import { SystemApi, SettingsApi } from "@/api";
import toast from "@/utils/toast";
import type { DocumentContent } from "@/api/settings";

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
let resizeListenerInstalled = false;

const isAgreed = ref(true);

// 协议对话框相关
const showAgreementDialog = ref(false);
const agreementDialogTitle = ref("用户协议");
const agreementDialogContent = ref("");

// 登录类型选项 - 根据验证码设置动态显示
const loginTabs = computed(() => {
  const tabs = [
    { label: "密码登录", value: "password" },
    { label: "注册", value: "register" },
  ];

  // 只有开启验证码时才显示验证码登录 tab
  if (requireCaptchaForLogin.value) {
    tabs.splice(1, 0, { label: "验证码登录", value: "captcha" });
  }

  return tabs;
});

// 窗口大小管理
let originalSize: { width: number; height: number } | null = null;
let originalResizable: boolean = true;

// 设置登录页面窗口大小
async function setLoginWindowSize() {
  const logId = `LOGIN_RESIZE_${Date.now()}`;
  
  if (isModalMode.value) {
    return;
  }

  if (store.getters.isLoggedIn) {
    return;
  }

  try {
    const currentWindow = getCurrentWebviewWindow();

    // 保存原始窗口大小和可调整状态
    const currentSize = await currentWindow.innerSize();
    
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
    }

    // 使用前端安全尺寸调整，避免小屏/高DPI溢出
    await setWindowSizeSafe(400, 650);
  } catch (error) {
    // 回退到前端方法
    try {
      await setWindowSizeSafe(400, 650);
    } catch (fallbackError) {
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
    }

    // 若记录的原始尺寸明显异常（例如高度远大于默认窗口），则回退为默认主窗口尺寸
    let sizeToRestore = DEFAULT_MAIN_WINDOW_SIZE;
    if (originalSize) {
      const heightLimit = DEFAULT_MAIN_WINDOW_SIZE.height * 1.5;
      const widthLimit = DEFAULT_MAIN_WINDOW_SIZE.width * 1.5;
      if (originalSize.height <= heightLimit && originalSize.width <= widthLimit) {
        sizeToRestore = originalSize;
      }
    }

    await setWindowSizeSafe(sizeToRestore.width, sizeToRestore.height);
  } catch (error) {
    // 回退到前端方法
    const fallbackSize = originalSize ?? DEFAULT_MAIN_WINDOW_SIZE;
    try {
      await setWindowSizeSafe(fallbackSize.width, fallbackSize.height);
    } catch (fallbackError) {
    }
  }
}

// 加载验证码设置
async function loadCaptchaSetting() {
  try {
    const response = await SettingsApi.getCaptchaSetting();
    if (response.success && response.data) {
      const newCaptchaSetting = response.data.require_captcha_for_login;
      const oldCaptchaSetting = requireCaptchaForLogin.value;

      requireCaptchaForLogin.value = newCaptchaSetting;

      // 如果验证码设置发生变化，调整当前登录类型
      if (newCaptchaSetting !== oldCaptchaSetting) {
        // 如果关闭了验证码但当前是验证码登录，切换到密码登录
        if (!newCaptchaSetting && loginType.value === 'captcha') {
          loginType.value = 'password';
          loginForm.value.captcha = '';
        }
        // 如果开启验证码，可以保持当前选择
      }
    }
  } catch (error) {
    // 静默失败，使用默认值 false
  }
}

// 从本地存储加载上次登录的账号
function loadLastLoginAccount() {
  try {
    const lastAccount = localStorage.getItem('lastLoginAccount');
    if (lastAccount) {
      loginForm.value.phone = lastAccount;
    }
  } catch (error) {
    // 静默失败
  }
}

// 保存本次登录的账号到本地存储
function saveLastLoginAccount(account: string) {
  try {
    localStorage.setItem('lastLoginAccount', account);
  } catch (error) {
    // 静默失败
  }
}

// 组件挂载时设置窗口大小
onMounted(() => {
  try {
    store.dispatch("hideGlobalLoading");
  } catch (error) {
  }

  // 加载上次登录的账号
  loadLastLoginAccount();

  // 加载验证码设置
  void loadCaptchaSetting();

  // 添加短暂延迟确保路由跳转完成
  if (!isModalMode.value) {
    if (!resizeListenerInstalled) {
      resizeListenerInstalled = true;
      void installUserResizeListener();
      resetUserResizedFlag();
    }
    loginWindowTimer = window.setTimeout(() => {
      loginWindowTimer = null;
      void setLoginWindowSize();
    }, 120);
  }
});

// 切换到注册
function switchToRegister() {
  loginType.value = "register";
  loginForm.value.password = "";
  loginForm.value.confirmPassword = "";
  loginForm.value.captcha = DEFAULT_CAPTCHA;
}

// 切换到登录
function switchToLogin() {
  loginType.value = "password";
  loginForm.value.password = "";
  loginForm.value.confirmPassword = "";
  loginForm.value.captcha = DEFAULT_CAPTCHA;
}

// 处理注册
async function handleRegister() {
  // 表单验证
  if (!validateRegisterForm()) {
    return;
  }

  isLoading.value = true;

  try {
    // 邮箱自动生成：手机号 + @example.com
    const email = `${loginForm.value.phone}@example.com`;

    // 调用注册接口
    const registerResponse = await SystemApi.register({
      username: loginForm.value.phone,
      email: email,
      password: loginForm.value.password,
    });

    if (registerResponse.success && registerResponse.data) {
      // 注册成功，自动登录
      const { setLoggingOut, setLoginTime, clearLoginTime } = await import(
        "@/api/http"
      );
      setLoggingOut(false);
      clearLoginTime();

      // 使用密码登录
      const loginResponse = await SystemApi.login({
        mobile: loginForm.value.phone,
        password: loginForm.value.password,
        userDeviceId: Date.now(),
      });

      if (loginResponse.success && loginResponse.data) {
        setLoginTime();

        // 保存本次登录的账号
        saveLastLoginAccount(loginForm.value.phone);

        const userInfo = loginResponse.data.userInfo;
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

        await store.dispatch("login", {
          token: loginResponse.data.token,
          refreshToken: loginResponse.data.refreshToken ?? null,
          userInfo: mappedUserInfo,
        });

        // 将账号添加到 accounts 模块
        try {
          const accountInfo = {
            id: mappedUserInfo.id,
            token: loginResponse.data.token,
            refreshToken: loginResponse.data.refreshToken ?? null,
            userInfo: mappedUserInfo,
            unreadCount: 0,
            friendRequestCount: 0,
            createdAt: Date.now()
          };

          const existingAccount = store.getters['accounts/getAccountById'](mappedUserInfo.id);
          if (existingAccount) {
            await store.commit('accounts/UPDATE_ACCOUNT', {
              accountId: mappedUserInfo.id,
              data: accountInfo
            });
          } else {
            await store.dispatch('accounts/addAccount', accountInfo);
          }

          await store.dispatch('accounts/switchAccount', mappedUserInfo.id);
        } catch (accountError) {
        }

        await new Promise((resolve) => setTimeout(resolve, 800));

        const verifyToken = store.state.token;
        const verifyLoggedIn = store.getters.isLoggedIn;

        if (!verifyToken || verifyToken !== loginResponse.data.token) {
          await store.dispatch("login", {
            token: loginResponse.data.token,
            refreshToken: loginResponse.data.refreshToken ?? null,
            userInfo: mappedUserInfo,
          });
          await new Promise((resolve) => setTimeout(resolve, 500));
        }

        try {
          const { updateWindowTitle } = await import("@/utils");
          const appName = store.state.appName;
          await updateWindowTitle(mappedUserInfo, appName);
        } catch (error) {
        }

        try {
          const { UserApi } = await import("@/api");
          await UserApi.syncAvatarCache(true);
        } catch (avatarError) {
        }

        await new Promise((resolve) => setTimeout(resolve, 200));

        const finalToken = store.state.token;
        const finalLoggedIn = store.getters.isLoggedIn;

        if (finalToken && finalLoggedIn) {
          const successPayload = {
            accountId: mappedUserInfo.id,
            nickname: mappedUserInfo.nickname,
          };

          if (isModalMode.value) {
            emit("login-success", successPayload);
            return;
          }

          try {
            const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
            const currentWindow = getCurrentWebviewWindow();
            const windowLabel = currentWindow.label;

            if (windowLabel.startsWith('login-')) {
              try {
                const { emit } = await import('@tauri-apps/api/event');
                await emit('account-added', {
                  accountId: mappedUserInfo.id,
                  nickname: mappedUserInfo.nickname
                });
              } catch (error) {
              }

              await new Promise(resolve => setTimeout(resolve, 500));
              await currentWindow.close();
              return;
            }
          } catch (error) {
          }

          // 注册后自动登录成功，恢复窗口可调整状态
          try {
            const currentWindow = getCurrentWebviewWindow();
            await currentWindow.setResizable(true);
          } catch (error) {
            // 静默处理权限错误
          }

          router.replace({ name: "Home" });
        } else {
          toast.error("登录状态异常，请重试");
        }
      } else {
        toast.error(loginResponse.message || "自动登录失败，请手动登录");
      }
    } else {
      // 注册失败，使用 API 返回的错误消息
      toast.error(registerResponse.message || "注册失败，请检查输入信息");
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息，如果没有则使用错误对象的 message
    const errorMessage = error?.response?.message || error?.message || "网络错误，请稍后重试";
    toast.error(errorMessage);
  } finally {
    isLoading.value = false;
  }
}

// 处理提交（登录或注册）
async function handleSubmit() {
  if (loginType.value === "register") {
    await handleRegister();
  } else {
    await handleLogin();
  }
}

// 处理登录
async function handleLogin() {
  // 表单验证
  if (!validateForm()) {
    return;
  }

  isLoading.value = true;

  try {
    // 在开始登录前立即重置登出状态，确保可以发起API请求
    const { setLoggingOut, setLoginTime, clearLoginTime } = await import(
      "@/api/http"
    );
    setLoggingOut(false);
    clearLoginTime(); // 清除之前的登录时间

    let response;

    if (loginType.value === "password") {
      // 密码登录
      if (requireCaptchaForLogin.value) {
        // 如果开启验证码，需要使用短信登录接口
        response = await SystemApi.loginWithSMS({
          phone: loginForm.value.phone,
          code: loginForm.value.captcha,
        });
      } else {
        response = await SystemApi.login({
          mobile: loginForm.value.phone,
          password: loginForm.value.password,
          userDeviceId: Date.now(),
        });
      }
    } else {
      // 验证码登录
      response = await SystemApi.loginWithSMS({
        phone: loginForm.value.phone,
        code: loginForm.value.captcha,
      });
    }

    if (response.success && response.data) {
      // 登录成功，立即设置登录时间（在状态更新之前）
      setLoginTime();

      // 保存本次登录的账号
      saveLastLoginAccount(loginForm.value.phone);

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


      await store.dispatch("login", {
        token: response.data.token,
        refreshToken: response.data.refreshToken ?? null,
        userInfo: mappedUserInfo,
      });

      // 将账号添加到 accounts 模块（支持多账号）
      try {
        const accountInfo = {
          id: mappedUserInfo.id,
          token: response.data.token,
          refreshToken: response.data.refreshToken ?? null,
          userInfo: mappedUserInfo,
          unreadCount: 0,
          friendRequestCount: 0,
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
        } else {
          // 添加新账号
          await store.dispatch('accounts/addAccount', accountInfo);
        }

        // 设置为当前账号
        await store.dispatch('accounts/switchAccount', mappedUserInfo.id);
      } catch (accountError) {
        // 不阻断登录流程，只记录错误
      }


      // 等待更长时间确保状态完全同步，避免竞态条件
      await new Promise((resolve) => setTimeout(resolve, 800)); // 增加延迟

      // 验证token是否正确设置到store中
      const verifyToken = store.state.token;
      const verifyLoggedIn = store.getters.isLoggedIn;

      // 如果token验证失败，重新设置
      if (!verifyToken || verifyToken !== response.data.token) {
        await store.dispatch("login", {
          token: response.data.token,
          refreshToken: response.data.refreshToken ?? null,
          userInfo: mappedUserInfo,
        });
        // 再次等待确保设置完成
        await new Promise((resolve) => setTimeout(resolve, 500));
      }

      // 更新窗口标题
      try {
        const { updateWindowTitle } = await import("@/utils");
        const appName = this.$store.state.appName;
        await updateWindowTitle(mappedUserInfo, appName);
      } catch (error) {
      }

      // 同步头像缓存
      try {
        const { UserApi } = await import("@/api");
        await UserApi.syncAvatarCache(true);
      } catch (avatarError) {
      }

      // 最后等待确保所有异步操作完成
      await new Promise((resolve) => setTimeout(resolve, 200));

      // 登录成功跳转前的最终状态确认
      const finalToken = store.state.token;
      const finalLoggedIn = store.getters.isLoggedIn;

      // 只有在状态确认无误时才跳转
      if (finalToken && finalLoggedIn) {

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


          // 如果是独立的登录窗口（label以'login-'开头）
          if (windowLabel.startsWith('login-')) {

            // 通知主窗口刷新账号列表
            try {
              const { emit } = await import('@tauri-apps/api/event');
              await emit('account-added', {
                accountId: mappedUserInfo.id,
                nickname: mappedUserInfo.nickname
              });
            } catch (error) {
            }

            // 延迟关闭窗口，让用户看到成功提示
            await new Promise(resolve => setTimeout(resolve, 500));
            await currentWindow.close();
            return;
          }
        } catch (error) {
        }

        // 登录成功，立即恢复窗口可调整状态（不等待组件卸载）
        try {
          const currentWindow = getCurrentWebviewWindow();
          await currentWindow.setResizable(true);
        } catch (error) {
          // 静默处理权限错误
        }

        // 主窗口登录，跳转到首页
        router.replace({ name: "Home" });
      } else {
        toast.error("登录状态异常，请重试");
      }
    } else {
      // 登录失败，使用 API 返回的错误消息
      toast.error(response.message || "登录失败，请检查账号密码");
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息，如果没有则使用错误对象的 message
    const errorMessage = error?.response?.message || error?.message || "网络错误，请稍后重试";
    toast.error(errorMessage);
  } finally {
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

// 表单数据 - 默认不预填任何账号信息
const DEFAULT_CAPTCHA = "";

// 登录/注册表单，初始值为空，由用户手动填写
const loginForm = ref({
  phone: "",
  password: "",
  confirmPassword: "",
  captcha: "",
});

// 登录类型：password 密码登录 | captcha 验证码登录 | register 注册
const loginType = ref<"password" | "captcha" | "register">("password");
// 是否需要验证码
const requireCaptchaForLogin = ref(false);

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
  if (loginType.value === "register") {
    return (
      account.length > 0 &&
      loginForm.value.password.length >= 6 &&
      loginForm.value.captcha.length === 6 &&
      isAgreed.value
    );
  }
  if (loginType.value === "password") {
    const needsCaptcha = requireCaptchaForLogin.value;
    return (
      account.length > 0 &&
      loginForm.value.password.length >= 6 &&
      (!needsCaptcha || loginForm.value.captcha.length === 6) &&
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
    loginForm.value.confirmPassword = "";
  } else if (value === "register") {
    loginForm.value.password = "";
    loginForm.value.confirmPassword = "";
    loginForm.value.captcha = DEFAULT_CAPTCHA;
  } else {
    loginForm.value.password = "";
    loginForm.value.confirmPassword = "";
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

  if (!isCaptchaMode && loginType.value !== "register") {
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

    // 如果开启验证码，需要验证码
    if (requireCaptchaForLogin.value) {
      if (!loginForm.value.captcha.trim()) {
        toast.error("请输入验证码");
        return false;
      }

      if (loginForm.value.captcha.length !== 6) {
        toast.error("验证码长度为6位");
        return false;
      }
    }
  } else if (loginType.value === "register") {
    // 注册表单验证在 validateRegisterForm 中处理
    return validateRegisterForm();
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

// 注册表单验证函数
function validateRegisterForm(): boolean {
  const account = loginForm.value.phone.trim();

  if (!account) {
    toast.error("请输入手机号");
    return false;
  }

  const phoneValue = loginForm.value.phone;
  const isAllDigits = /^\d+$/.test(phoneValue);
  if (isAllDigits && phoneValue.length !== 11) {
    toast.error("请输入正确的手机号");
    return false;
  }

  if (!loginForm.value.password.trim()) {
    toast.error("请输入密码");
    return false;
  }

  if (loginForm.value.password.length < 6) {
    toast.error("密码长度至少为6位");
    return false;
  }

  // 验证验证码（如果开启验证码）
  if (requireCaptchaForLogin.value) {
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
    toast.error(error.message || "网络错误，请稍后重试");
  } finally {
    isSendingCaptcha.value = false;
  }
}

// 处理键盘事件（回车提交）
function handleKeydown(event: KeyboardEvent) {
  if (event.key === "Enter") {
    event.preventDefault();
    handleSubmit();
  }
}

// 显示用户协议
async function showUserAgreement() {
  try {
    const response = await SettingsApi.getUserAgreement();
    if (response.code === 200 && response.data) {
      agreementDialogTitle.value = response.data.title || "用户协议";
      agreementDialogContent.value = response.data.content || "";
      showAgreementDialog.value = true;
    } else {
      toast.error(response.message || "加载用户协议失败");
    }
  } catch (error: any) {
    toast.error(error.message || "加载用户协议失败，请稍后重试");
  }
}

// 显示隐私协议
async function showPrivacyAgreement() {
  try {
    const response = await SettingsApi.getPrivacyPolicy();
    if (response.code === 200 && response.data) {
      agreementDialogTitle.value = response.data.title || "隐私协议";
      agreementDialogContent.value = response.data.content || "";
      showAgreementDialog.value = true;
    } else {
      toast.error(response.message || "加载隐私协议失败");
    }
  } catch (error: any) {
    toast.error(error.message || "加载隐私协议失败，请稍后重试");
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

  // 禁用文字选中，保持默认鼠标状态
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
  cursor: default;

  // 表单输入框允许选中
  input,
  textarea {
    -webkit-user-select: text;
    -moz-user-select: text;
    -ms-user-select: text;
    user-select: text;
    cursor: text;
  }

  // b-input 组件内部的 input
  :deep(.b-input input) {
    -webkit-user-select: text;
    -moz-user-select: text;
    -ms-user-select: text;
    user-select: text;
    cursor: text;
  }

  // 按钮保持 pointer
  button,
  .login-container-form-switch-link,
  .agreement-link {
    cursor: pointer;
  }

  // b-button 和 b-radio 组件
  :deep(.b-button),
  :deep(.b-radio) {
    cursor: pointer;
  }

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
        line-height: 1.4;

        .agreement-link {
          color: var(--primary-color);
          text-decoration: none;
          transition: opacity 0.2s ease;

          &:hover {
            text-decoration: underline;
            opacity: 0.8;
          }
        }
      }
    }

    &-switch {
      margin-top: 16px;
      text-align: center;
      font-size: 14px;

      &-text {
        color: var(--text-secondary);
      }

      &-link {
        color: var(--primary-color);
        margin-left: 4px;
        font-weight: 500;

        &:hover {
          text-decoration: underline;
        }
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
