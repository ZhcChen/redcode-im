<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from '@/stores/auth';

type LoginMode = 'login' | 'register';

const router = useRouter();
const authStore = useAuthStore();

const mode = ref<LoginMode>('login');
const account = ref('');
const password = ref('');
const agreed = ref(window.localStorage.getItem('redcode-h5-agreed') === 'true');
const message = ref('');

const isRegister = computed(() => mode.value === 'register');
const submitText = computed(() => (isRegister.value ? '注册账号' : '登录账号'));

const accountPattern = /^[a-zA-Z0-9._-]{3,20}$/;

const toggleAgreement = () => {
  agreed.value = !agreed.value;
  window.localStorage.setItem('redcode-h5-agreed', String(agreed.value));
};

const switchMode = () => {
  mode.value = isRegister.value ? 'login' : 'register';
  message.value = '';
};

const submit = async () => {
  const normalizedAccount = account.value.trim().toLowerCase();
  message.value = '';

  if (!agreed.value) {
    message.value = '请勾选并阅读《用户协议》和《隐私协议》';
    return;
  }
  if (!normalizedAccount || !password.value) {
    message.value = isRegister.value ? '请填写完整的注册信息' : '请输入完整的账号和密码';
    return;
  }
  if (!accountPattern.test(normalizedAccount)) {
    message.value = '账号需为 3-20 位字母、数字、点、下划线或短横线';
    return;
  }

  try {
    if (isRegister.value) {
      await authStore.registerAndLogin(normalizedAccount, password.value);
    } else {
      await authStore.login(normalizedAccount, password.value);
    }
    await router.replace({ name: 'home' });
  } catch (error) {
    message.value = error instanceof Error ? error.message : '网络异常，请稍后重试';
  }
};
</script>

<template>
  <main class="login-page">
    <section class="login-page__frame app-phone-frame">
      <div class="login-page__hero" aria-hidden="true">
        <div class="login-page__orb login-page__orb--left" />
        <div class="login-page__orb login-page__orb--right" />
      </div>

      <div class="login-page__content">
        <header class="login-page__greeting">
          <h1>你好！</h1>
          <div class="login-page__subtitle-row">
            <p>欢迎来到 RedCode IM</p>
            <strong>CHATLY</strong>
          </div>
        </header>

        <form class="login-card" @submit.prevent="submit">
          <div class="login-card__tabs" role="tablist" aria-label="登录方式">
            <button
              type="button"
              class="login-card__tab rc-focus-ring"
              :class="{ 'login-card__tab--active': mode === 'login' }"
              role="tab"
              :aria-selected="mode === 'login'"
              @click="mode = 'login'"
            >
              密码登录
            </button>
            <button
              type="button"
              class="login-card__tab rc-focus-ring"
              :class="{ 'login-card__tab--active': mode === 'register' }"
              role="tab"
              :aria-selected="mode === 'register'"
              @click="mode = 'register'"
            >
              注册
            </button>
          </div>

          <div class="login-card__body">
            <label class="login-field">
              <span>账号</span>
              <input
                v-model="account"
                class="rc-focus-ring"
                autocomplete="username"
                inputmode="text"
                type="text"
                placeholder="请输入账号"
                :disabled="authStore.loading"
              />
            </label>

            <label class="login-field">
              <span>{{ isRegister ? '设置密码' : '密码' }}</span>
              <input
                v-model="password"
                class="rc-focus-ring"
                :autocomplete="isRegister ? 'new-password' : 'current-password'"
                type="password"
                :placeholder="isRegister ? '请设置您的登录密码' : '请输入登录密码'"
                :disabled="authStore.loading"
              />
            </label>

            <p v-if="message || authStore.error" class="login-card__message" role="alert">
              {{ message || authStore.error }}
            </p>

            <button class="login-card__submit rc-focus-ring" type="submit" :disabled="authStore.loading">
              <span v-if="authStore.loading">处理中...</span>
              <span v-else>{{ submitText }}</span>
            </button>

            <button class="login-card__agreement rc-focus-ring" type="button" @click="toggleAgreement">
              <span class="login-card__radio" :class="{ 'login-card__radio--checked': agreed }" aria-hidden="true" />
              <span>
                注册/登录即代表同意
                <em>《用户协议》</em>
                和
                <em>《隐私协议》</em>
              </span>
            </button>

            <div class="login-card__switch">
              <span>{{ isRegister ? '已有账号' : '新用户' }}</span>
              <button class="rc-focus-ring" type="button" @click="switchMode">
                {{ isRegister ? '立即登录' : '立即注册' }}
              </button>
            </div>

            <button v-if="!isRegister" class="login-card__forgot rc-focus-ring" type="button">
              忘记密码
            </button>
          </div>
        </form>
      </div>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  min-height: 100dvh;
  background: var(--rc-background);
}

.login-page__frame {
  position: relative;
  overflow: hidden;
  background:
    radial-gradient(circle at 22% 8%, rgb(255 255 255 / 42%) 0 18%, transparent 19%),
    linear-gradient(180deg, var(--rc-primary-soft) 0%, #ddfbf8 34%, var(--rc-background) 78%);
}

.login-page__hero {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

.login-page__orb {
  position: absolute;
  border-radius: 999px;
  background: rgb(255 255 255 / 32%);
  filter: blur(1px);
}

.login-page__orb--left {
  width: 168px;
  height: 168px;
  left: -64px;
  top: 78px;
}

.login-page__orb--right {
  width: 220px;
  height: 220px;
  right: -96px;
  top: 18px;
}

.login-page__content {
  position: relative;
  z-index: 1;
  min-height: 100dvh;
  padding: calc(var(--rc-safe-top) + 48px) 16px 32px;
}

.login-page__greeting {
  padding: 0 8px;
}

.login-page__greeting h1 {
  margin: 0;
  color: var(--rc-text-black);
  font-size: 32px;
  font-weight: 600;
  letter-spacing: -0.03em;
}

.login-page__subtitle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-top: 8px;
}

.login-page__subtitle-row p {
  margin: 0;
  color: var(--rc-text-black);
  font-size: 16px;
}

.login-page__subtitle-row strong {
  color: var(--rc-primary-strong);
  font-size: 18px;
  font-style: italic;
  letter-spacing: -0.04em;
}

.login-card {
  margin-top: 32px;
  overflow: hidden;
  border: 2px solid rgb(255 255 255 / 92%);
  border-radius: var(--rc-radius-card);
  background: rgb(255 255 255 / 92%);
  box-shadow: var(--rc-shadow-card);
}

.login-card__tabs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  height: 72px;
  background: var(--rc-surface-muted);
}

.login-card__tab {
  position: relative;
  cursor: pointer;
  background: rgb(255 255 255 / 42%);
  color: var(--rc-text-black);
  font-size: 14px;
  transition:
    background 180ms ease,
    font-weight 180ms ease;
}

.login-card__tab--active {
  border-radius: 28px 28px 0 0;
  background: var(--rc-surface);
  font-weight: 600;
}

.login-card__tab--active::after {
  position: absolute;
  left: 50%;
  bottom: 16px;
  width: 32px;
  height: 4px;
  border-radius: 2px;
  background: var(--rc-primary);
  content: "";
  transform: translateX(-50%);
}

.login-card__body {
  display: grid;
  gap: 24px;
  padding: 32px 24px;
}

.login-field {
  display: grid;
  gap: 12px;
}

.login-field span {
  padding-left: 12px;
  color: var(--rc-text-black);
  font-size: 14px;
  font-weight: 500;
}

.login-field input {
  width: 100%;
  height: 44px;
  border: 0;
  border-radius: 44px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  font-size: 14px;
  padding: 0 24px;
}

.login-field input::placeholder {
  color: var(--rc-text-secondary);
}

.login-card__message {
  margin: -8px 0 0;
  border-radius: 16px;
  background: #feeceb;
  color: var(--rc-danger);
  font-size: 13px;
  line-height: 1.5;
  padding: 10px 14px;
}

.login-card__submit {
  min-height: 44px;
  cursor: pointer;
  border-radius: var(--rc-radius-control);
  background: var(--rc-primary);
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  transition:
    transform 160ms ease,
    opacity 160ms ease;
}

.login-card__submit:active {
  transform: scale(0.99);
}

.login-card__submit:disabled {
  cursor: not-allowed;
  opacity: 0.62;
}

.login-card__agreement {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-tertiary);
  font-size: 11px;
  line-height: 1.5;
  text-align: left;
}

.login-card__agreement em {
  color: var(--rc-primary);
  font-style: normal;
}

.login-card__radio {
  position: relative;
  flex: 0 0 auto;
  width: 14px;
  height: 14px;
  border: 1px solid var(--rc-primary);
  border-radius: 999px;
  background: #fff;
}

.login-card__radio--checked {
  background: var(--rc-primary);
}

.login-card__radio--checked::after {
  position: absolute;
  left: 4px;
  top: 2px;
  width: 4px;
  height: 7px;
  border: solid #fff;
  border-width: 0 2px 2px 0;
  content: "";
  transform: rotate(45deg);
}

.login-card__switch {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  margin-top: 16px;
  color: var(--rc-text-secondary);
  font-size: 14px;
}

.login-card__switch button,
.login-card__forgot {
  cursor: pointer;
  background: transparent;
  color: var(--rc-primary);
  font-weight: 600;
}

.login-card__forgot {
  color: var(--rc-text-secondary);
  font-size: 14px;
  font-weight: 400;
}
</style>
