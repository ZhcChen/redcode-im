<template>
  <div class="login-page">
    <section class="login-card">
      <h1 class="login-title">登录桌面客户端</h1>
      <p class="login-subtitle">使用 Redcode IM 账号继续对话</p>

      <form class="login-form" @submit.prevent="handleSubmit">
        <label class="form-label" for="username">用户名</label>
        <input
          id="username"
          v-model="form.username"
          type="text"
          autocomplete="username"
          class="form-input"
          placeholder="输入用户名"
          required
        />

        <label class="form-label" for="password">密码</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          autocomplete="current-password"
          class="form-input"
          placeholder="输入密码"
          required
        />

        <p v-if="errorMessage" class="error-text">{{ errorMessage }}</p>

        <button type="submit" class="submit-button" :disabled="loading">
          {{ loading ? '正在登录...' : '登录' }}
        </button>
      </form>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import type { RootState } from '@/store';

const store = useStore<RootState>();
const router = useRouter();

const form = reactive({
  username: '',
  password: '',
});

const loading = ref(false);
const errorMessage = ref('');

const isLoggedIn = computed(() => store.getters.isLoggedIn);

if (isLoggedIn.value) {
  router.replace({ name: 'AppShell' });
}

const handleSubmit = async () => {
  if (!form.username || !form.password) {
    errorMessage.value = '请输入用户名和密码';
    return;
  }

  loading.value = true;
  errorMessage.value = '';

  try {
    await store.dispatch('login', {
      username: form.username.trim(),
      password: form.password,
    });
    await Promise.all([
      store.dispatch('fetchChats'),
      store.dispatch('fetchFriends'),
      store.dispatch('fetchFriendRequests'),
    ]);
    router.replace({ name: 'AppShell' });
  } catch (error) {
    errorMessage.value = (error as Error).message || '登录失败，请稍后再试';
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #4ecdc4, #556270);
}

.login-card {
  width: min(420px, 90vw);
  padding: 40px 36px;
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.18);
}

.login-title {
  margin: 0 0 8px;
  font-size: 28px;
  font-weight: 700;
  color: #1f2d3d;
}

.login-subtitle {
  margin: 0 0 32px;
  font-size: 15px;
  color: #5c6b7a;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-label {
  font-size: 14px;
  color: #394b59;
}

.form-input {
  padding: 12px 14px;
  border: 1px solid #d4dfe6;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.9);
  font-size: 15px;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.form-input:focus {
  outline: none;
  border-color: #4ecdc4;
  box-shadow: 0 0 0 3px rgba(78, 205, 196, 0.3);
}

.error-text {
  margin: 0;
  color: #ff4d4f;
  font-size: 14px;
}

.submit-button {
  margin-top: 8px;
  padding: 12px;
  border: none;
  border-radius: 10px;
  font-size: 16px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #4ecdc4, #289f9f);
  cursor: pointer;
  transition: transform 0.2s ease, opacity 0.2s ease;
}

.submit-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.submit-button:not(:disabled):hover {
  transform: translateY(-1px);
}
</style>
