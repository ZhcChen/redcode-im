<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import AgreementModal from "./AgreementModal.vue";
import { SettingsApi, type DocumentContent } from "@/api/settings";
import { SystemApi, type LegacyUserInfo } from "@/api/system";

type LoginType = "password" | "captcha" | "register";
type NoticeTone = "neutral" | "success" | "error";

const props = defineProps<{
  appName: string;
  hostVersion: string | null;
  runtimeAvailable: boolean;
}>();

const emit = defineEmits<{
  (event: "login-success", payload: { token: string; user: LegacyUserInfo }): void;
}>();

const loginType = ref<LoginType>("password");
const requireCaptchaForLogin = ref(false);
const isAgreed = ref(true);
const isLoading = ref(false);
const isSendingCaptcha = ref(false);
const countdown = ref(0);
const isPasswordVisible = ref(false);
const noticeMessage = ref("Go core 已就绪，当前入口开始接管旧桌面端登录 UI。");
const noticeTone = ref<NoticeTone>("neutral");
const agreementTitle = ref("协议内容");
const agreementContent = ref("");
const agreementVisible = ref(false);

const loginForm = ref({
  phone: "",
  password: "",
  confirmPassword: "",
  captcha: ""
});

let countdownTimer: number | null = null;

const loginTabs = computed(() => {
  const tabs: Array<{ label: string; value: LoginType }> = [
    { label: "密码登录", value: "password" },
    { label: "注册", value: "register" }
  ];
  if (requireCaptchaForLogin.value) {
    tabs.splice(1, 0, { label: "验证码登录", value: "captcha" });
  }
  return tabs;
});

const primaryFieldLabel = computed(() => (loginType.value === "captcha" ? "账号" : "账号 / 手机号"));
const primaryFieldPlaceholder = computed(() =>
  loginType.value === "captcha" ? "请输入账号" : "请输入账号或手机号"
);
const passwordToggleLabel = computed(() => (isPasswordVisible.value ? "隐藏" : "显示"));
const canSubmit = computed(() => {
  if (isLoading.value || !props.runtimeAvailable) {
    return false;
  }
  const account = loginForm.value.phone.trim();
  if (loginType.value === "register") {
    return account.length > 0 && loginForm.value.password.length >= 6 && isAgreed.value;
  }
  if (loginType.value === "password") {
    return account.length > 0 && loginForm.value.password.length >= 6 && isAgreed.value;
  }
  return account.length > 0 && loginForm.value.captcha.length === 6 && isAgreed.value;
});

const setNotice = (tone: NoticeTone, message: string) => {
  noticeTone.value = tone;
  noticeMessage.value = message;
};

const loadLastLoginAccount = () => {
  try {
    const account = window.localStorage.getItem("lastLoginAccount");
    if (account) {
      loginForm.value.phone = account;
    }
  } catch {
    // Ignore browser storage failures.
  }
};

const saveLastLoginAccount = (account: string) => {
  try {
    window.localStorage.setItem("lastLoginAccount", account);
  } catch {
    // Ignore browser storage failures.
  }
};

const loadCaptchaSetting = async () => {
  if (!props.runtimeAvailable) {
    setNotice("error", "当前仅浏览器预览模式，认证调用需要 Electron 宿主。");
    return;
  }

  try {
    const response = await SettingsApi.getCaptchaSetting();
    if (response.success && response.data) {
      requireCaptchaForLogin.value = response.data.require_captcha_for_login;
      if (!requireCaptchaForLogin.value && loginType.value === "captcha") {
        loginType.value = "password";
      }
    }
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "加载验证码设置失败");
  }
};

const openDocument = async (
  loader: () => Promise<{ success: boolean; data: DocumentContent | null; message: string }>
) => {
  if (!props.runtimeAvailable) {
    setNotice("error", "当前仅浏览器预览模式，协议内容需要 Electron 宿主。");
    return;
  }

  try {
    const response = await loader();
    if (!response.success || !response.data) {
      setNotice("error", response.message || "加载协议失败");
      return;
    }

    agreementTitle.value = response.data.title;
    agreementContent.value = response.data.content;
    agreementVisible.value = true;
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "加载协议失败");
  }
};

const validateAccount = (account: string, message: string) => {
  if (!account) {
    setNotice("error", message);
    return false;
  }
  const isAllDigits = /^\d+$/.test(account);
  if (isAllDigits && account.length !== 11) {
    setNotice("error", "请输入正确的手机号");
    return false;
  }
  return true;
};

const validateRegisterForm = () => {
  const account = loginForm.value.phone.trim();
  if (!validateAccount(account, "请输入手机号")) {
    return false;
  }
  if (!loginForm.value.password.trim()) {
    setNotice("error", "请输入密码");
    return false;
  }
  if (loginForm.value.password.length < 6) {
    setNotice("error", "密码长度至少为6位");
    return false;
  }
  if (requireCaptchaForLogin.value) {
    if (!loginForm.value.captcha.trim()) {
      setNotice("error", "请输入验证码");
      return false;
    }
    if (loginForm.value.captcha.length !== 6) {
      setNotice("error", "验证码长度为6位");
      return false;
    }
  }
  if (!isAgreed.value) {
    setNotice("error", "请先同意用户协议和隐私协议");
    return false;
  }
  return true;
};

const validateLoginForm = () => {
  const account = loginForm.value.phone.trim();
  if (!validateAccount(account, loginType.value === "captcha" ? "请输入账号" : "请输入手机号")) {
    return false;
  }

  if (loginType.value === "password") {
    if (!loginForm.value.password.trim()) {
      setNotice("error", "请输入密码");
      return false;
    }
    if (loginForm.value.password.length < 6) {
      setNotice("error", "密码长度至少为6位");
      return false;
    }
    if (requireCaptchaForLogin.value) {
      if (!loginForm.value.captcha.trim()) {
        setNotice("error", "请输入验证码");
        return false;
      }
      if (loginForm.value.captcha.length !== 6) {
        setNotice("error", "验证码长度为6位");
        return false;
      }
    }
  }

  if (loginType.value === "captcha") {
    if (!loginForm.value.captcha.trim()) {
      setNotice("error", "请输入验证码");
      return false;
    }
    if (loginForm.value.captcha.length !== 6) {
      setNotice("error", "验证码长度为6位");
      return false;
    }
  }

  if (!isAgreed.value) {
    setNotice("error", "请先同意用户协议和隐私协议");
    return false;
  }

  return true;
};

const handleTabChange = (tab: LoginType) => {
  loginType.value = tab;
  loginForm.value.password = "";
  loginForm.value.confirmPassword = "";
  loginForm.value.captcha = "";
  setNotice("neutral", "Go core 已就绪，当前入口开始接管旧桌面端登录 UI。");
};

const handleSendCaptcha = async () => {
  if (!props.runtimeAvailable) {
    setNotice("error", "当前仅浏览器预览模式，无法发送验证码。");
    return;
  }
  if (!loginForm.value.phone.trim()) {
    setNotice("error", "请输入账号");
    return;
  }

  isSendingCaptcha.value = true;
  try {
    const response = await SystemApi.sendLoginSMS({ phone: loginForm.value.phone });
    if (!response.success) {
      setNotice("error", response.message || "发送验证码失败");
      return;
    }

    setNotice("success", response.message || "验证码已发送");
    countdown.value = 60;
    if (countdownTimer) {
      window.clearInterval(countdownTimer);
    }
    countdownTimer = window.setInterval(() => {
      countdown.value -= 1;
      if (countdown.value <= 0 && countdownTimer) {
        window.clearInterval(countdownTimer);
        countdownTimer = null;
      }
    }, 1000);
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "发送验证码失败");
  } finally {
    isSendingCaptcha.value = false;
  }
};

const emitLoginSuccess = (token: string, user: LegacyUserInfo) => {
  saveLastLoginAccount(loginForm.value.phone.trim());
  setNotice("success", `登录成功，当前账号 ${user.nickname} 已接管 desktop-el 会话。`);
  emit("login-success", { token, user });
};

const handleRegister = async () => {
  if (!validateRegisterForm() || !props.runtimeAvailable) {
    return;
  }

  isLoading.value = true;
  try {
    const registerResponse = await SystemApi.register({
      username: loginForm.value.phone.trim(),
      email: `${loginForm.value.phone.trim()}@example.com`,
      password: loginForm.value.password,
      nickname: loginForm.value.phone.trim()
    });
    if (!registerResponse.success || !registerResponse.data) {
      setNotice("error", registerResponse.message || "注册失败，请检查输入信息");
      return;
    }

    const loginResponse = await SystemApi.login({
      mobile: loginForm.value.phone.trim(),
      password: loginForm.value.password,
      userDeviceId: Date.now()
    });
    if (!loginResponse.success || !loginResponse.data) {
      setNotice("error", loginResponse.message || "自动登录失败，请手动登录");
      return;
    }

    emitLoginSuccess(loginResponse.data.token, loginResponse.data.userInfo);
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "注册失败，请稍后重试");
  } finally {
    isLoading.value = false;
  }
};

const handleLogin = async () => {
  if (!validateLoginForm() || !props.runtimeAvailable) {
    return;
  }

  isLoading.value = true;
  try {
    const response =
      loginType.value === "captcha" || (loginType.value === "password" && requireCaptchaForLogin.value)
        ? await SystemApi.loginWithSMS({
            phone: loginForm.value.phone.trim(),
            code: loginForm.value.captcha.trim()
          })
        : await SystemApi.login({
            mobile: loginForm.value.phone.trim(),
            password: loginForm.value.password,
            userDeviceId: Date.now()
          });

    if (!response.success || !response.data) {
      setNotice("error", response.message || "登录失败，请检查账号密码");
      return;
    }

    emitLoginSuccess(response.data.token, response.data.userInfo);
  } catch (error) {
    setNotice("error", error instanceof Error ? error.message : "网络错误，请稍后重试");
  } finally {
    isLoading.value = false;
  }
};

const handleSubmit = async () => {
  if (loginType.value === "register") {
    await handleRegister();
    return;
  }
  await handleLogin();
};

const handleKeydown = (event: KeyboardEvent) => {
  if (event.key === "Enter") {
    event.preventDefault();
    void handleSubmit();
  }
};

onMounted(() => {
  loadLastLoginAccount();
  if (props.runtimeAvailable) {
    void loadCaptchaSetting();
  }
});

onUnmounted(() => {
  if (countdownTimer) {
    window.clearInterval(countdownTimer);
  }
});

watch(
  () => props.runtimeAvailable,
  (available) => {
    if (available) {
      void loadCaptchaSetting();
      return;
    }
    if (!window.desktopEl) {
      setNotice("error", "当前仅浏览器预览模式，认证调用需要 Electron 宿主。");
    }
  },
  { immediate: true }
);
</script>

<template>
  <section class="login-container">
    <div class="login-container__texture" />
    <div class="login-container__header">
      <div class="login-container__header-copy">
        <div class="login-container__title">Hello!</div>
        <div class="login-container__subtitle">欢迎来到{{ props.appName }}</div>
      </div>
      <div class="login-container__brand">
        <span>{{ props.appName }}</span>
        <small>Electron + Go core</small>
      </div>
    </div>

    <div class="login-container__panel">
      <div class="login-container__notice" :class="`login-container__notice--${noticeTone}`">
        <span>{{ noticeMessage }}</span>
        <small v-if="props.hostVersion">host {{ props.hostVersion }}</small>
      </div>

      <div class="tabs">
        <button
          v-for="tab in loginTabs"
          :key="tab.value"
          type="button"
          class="tabs__item"
          :class="{ 'tabs__item--active': loginType === tab.value }"
          @click="handleTabChange(tab.value)"
        >
          {{ tab.label }}
        </button>
      </div>

      <label class="field">
        <span class="field__label">{{ primaryFieldLabel }}</span>
        <input
          v-model="loginForm.phone"
          class="field__control"
          :placeholder="primaryFieldPlaceholder"
          autocomplete="off"
          @keydown="handleKeydown"
        />
      </label>

      <label v-if="loginType === 'password' || loginType === 'register'" class="field">
        <span class="field__label">{{ loginType === "register" ? "设置密码" : "密码" }}</span>
        <div class="field__password">
          <input
            v-model="loginForm.password"
            class="field__control"
            :type="isPasswordVisible ? 'text' : 'password'"
            :placeholder="loginType === 'register' ? '请设置您的登录密码' : '请输入密码'"
            autocomplete="off"
            @keydown="handleKeydown"
          />
          <button type="button" class="field__toggle" @click="isPasswordVisible = !isPasswordVisible">
            {{ passwordToggleLabel }}
          </button>
        </div>
      </label>

      <label
        v-if="loginType === 'captcha' || (loginType === 'password' && requireCaptchaForLogin) || (loginType === 'register' && requireCaptchaForLogin)"
        class="field"
      >
        <span class="field__label">验证码</span>
        <div class="field__captcha">
          <input
            v-model="loginForm.captcha"
            class="field__control"
            placeholder="请输入验证码"
            autocomplete="off"
            @keydown="handleKeydown"
          />
          <button
            type="button"
            class="field__captcha-button"
            :disabled="isSendingCaptcha || countdown > 0 || !props.runtimeAvailable"
            @click="handleSendCaptcha"
          >
            {{
              countdown > 0
                ? `${countdown}s后重发`
                : isSendingCaptcha
                  ? "发送中..."
                  : "发送验证码"
            }}
          </button>
        </div>
      </label>

      <button type="button" class="submit-button" :disabled="!canSubmit" @click="handleSubmit">
        {{
          isLoading
            ? loginType === "register"
              ? "注册中..."
              : "登录中..."
            : loginType === "register"
              ? "注册账号"
              : "登录账号"
        }}
      </button>

      <div v-if="loginType !== 'register'" class="switch-row">
        <span class="switch-row__text">新用户？</span>
        <button type="button" class="switch-row__link" @click="handleTabChange('register')">立即注册</button>
      </div>

      <div v-else class="switch-row">
        <span class="switch-row__text">已有账号？</span>
        <button type="button" class="switch-row__link" @click="handleTabChange('password')">立即登录</button>
      </div>

      <div class="terms-row">
        <button type="button" class="terms-row__check" @click="isAgreed = !isAgreed">
          <span v-if="isAgreed" class="terms-row__check-dot">✓</span>
        </button>
        <div class="terms-row__text">
          注册/登录即代表同意
          <button type="button" class="terms-row__link" @click="openDocument(() => SettingsApi.getUserAgreement())">
            《用户协议》
          </button>
          和
          <button type="button" class="terms-row__link" @click="openDocument(() => SettingsApi.getPrivacyPolicy())">
            《隐私协议》
          </button>
        </div>
      </div>
    </div>

    <AgreementModal
      v-model:visible="agreementVisible"
      :title="agreementTitle"
      :html-content="agreementContent"
    />
  </section>
</template>

<style scoped>
.login-container {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  background:
    radial-gradient(circle at 20% 18%, rgba(255, 255, 255, 0.55), transparent 32%),
    radial-gradient(circle at 84% 12%, rgba(0, 194, 179, 0.18), transparent 18%),
    linear-gradient(180deg, #caf6f3 0%, #d7fbf5 40%, #ecfffb 100%);
  user-select: none;
}

.login-container__texture {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(135deg, rgba(255, 255, 255, 0.25), transparent 40%),
    repeating-linear-gradient(
      135deg,
      rgba(255, 255, 255, 0.18) 0,
      rgba(255, 255, 255, 0.18) 2px,
      transparent 2px,
      transparent 16px
    );
  mix-blend-mode: overlay;
  opacity: 0.8;
  pointer-events: none;
}

.login-container__header {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  padding: 52px 32px 0;
}

.login-container__title {
  font-size: 32px;
  font-weight: 700;
}

.login-container__subtitle {
  margin-top: 8px;
  font-size: 16px;
}

.login-container__brand {
  display: grid;
  justify-items: end;
  gap: 2px;
  color: #00554e;
}

.login-container__brand span {
  font-size: 22px;
  font-weight: 800;
  letter-spacing: 0.06em;
}

.login-container__brand small {
  font-size: 11px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.login-container__panel {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  gap: 24px;
  min-height: calc(100vh - 180px);
  margin: 40px 24px 0;
  padding: 18px 36px 28px;
  border-radius: 24px 24px 0 0;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 -10px 30px rgba(15, 23, 42, 0.03);
}

.login-container__notice {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
  padding: 12px 14px;
  border-radius: 16px;
  font-size: 13px;
  line-height: 1.5;
}

.login-container__notice small {
  flex-shrink: 0;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.login-container__notice--neutral {
  background: rgba(0, 194, 179, 0.08);
  color: #0f766e;
}

.login-container__notice--success {
  background: rgba(22, 163, 74, 0.1);
  color: var(--success-color);
}

.login-container__notice--error {
  background: rgba(220, 38, 38, 0.1);
  color: var(--error-color);
}

.tabs {
  display: flex;
  justify-content: center;
  gap: 32px;
  padding-bottom: 8px;
}

.tabs__item {
  position: relative;
  padding: 0 0 10px;
  color: var(--text-secondary);
  cursor: pointer;
}

.tabs__item--active {
  color: var(--primary-color-strong);
  font-weight: 700;
}

.tabs__item--active::after {
  content: "";
  position: absolute;
  left: 50%;
  bottom: 0;
  width: 56px;
  height: 4px;
  border-radius: 999px;
  background: var(--primary-color);
  transform: translateX(-50%);
}

.field {
  display: grid;
  gap: 12px;
}

.field__label {
  padding-left: 12px;
  font-size: 14px;
}

.field__control {
  width: 100%;
  height: 44px;
  border: 1px solid transparent;
  border-radius: 22px;
  padding: 0 18px;
  background: var(--bg-soft);
  outline: none;
  transition: border-color 0.18s ease, box-shadow 0.18s ease;
  user-select: text;
}

.field__control:focus {
  border-color: rgba(0, 194, 179, 0.38);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.12);
}

.field__password,
.field__captcha {
  display: flex;
  gap: 12px;
  align-items: center;
}

.field__password .field__control,
.field__captcha .field__control {
  flex: 1;
}

.field__toggle,
.field__captcha-button {
  flex-shrink: 0;
  height: 44px;
  border-radius: 22px;
  cursor: pointer;
}

.field__toggle {
  min-width: 72px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.field__captcha-button {
  min-width: 112px;
  padding: 0 16px;
  background: rgba(0, 194, 179, 0.1);
  color: var(--primary-color-strong);
}

.field__captcha-button:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.submit-button {
  height: 44px;
  width: 100%;
  border-radius: 22px;
  background: var(--primary-color);
  color: var(--text-white-color);
  cursor: pointer;
}

.submit-button:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.switch-row {
  display: flex;
  justify-content: center;
  gap: 4px;
  margin-top: -8px;
  font-size: 14px;
}

.switch-row__text {
  color: var(--text-secondary);
}

.switch-row__link,
.terms-row__link {
  color: var(--primary-color-strong);
  cursor: pointer;
}

.switch-row__link:hover,
.terms-row__link:hover {
  text-decoration: underline;
}

.terms-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: auto;
}

.terms-row__check {
  display: grid;
  place-items: center;
  width: 16px;
  height: 16px;
  border-radius: 999px;
  border: 1px solid var(--primary-color);
  background: #ffffff;
  color: #ffffff;
  cursor: pointer;
}

.terms-row__check-dot {
  display: inline-grid;
  place-items: center;
  width: 14px;
  height: 14px;
  border-radius: 999px;
  background: var(--primary-color);
  font-size: 10px;
}

.terms-row__text {
  color: var(--text-secondary);
  font-size: 11px;
  line-height: 1.45;
}

@media (max-width: 640px) {
  .login-container__header {
    flex-direction: column;
    align-items: flex-start;
    gap: 18px;
    padding: 32px 20px 0;
  }

  .login-container__panel {
    margin: 28px 12px 0;
    padding: 18px 18px 22px;
  }

  .field__password,
  .field__captcha {
    flex-direction: column;
  }

  .field__toggle,
  .field__captcha-button {
    width: 100%;
  }

  .login-container__notice {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
