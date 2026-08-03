<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { appEnv } from '@/config/env';
import { accountDataService } from '@/services/account-data-service';
import { authService } from '@/services/auth-service';
import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import { useContactsStore } from '@/stores/contacts';
import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const acknowledged = ref(false);
const confirming = ref(false);
const keyword = ref('');
const submitting = ref(false);
const error = ref('');

const deactivate = async () => {
  if (!acknowledged.value || keyword.value !== '注销' || submitting.value) return;
  submitting.value = true;
  error.value = '';
  try {
    if (!appEnv.useMockData) await authService.deactivateAccount();
    const chat = useChatStore();
    const contacts = useContactsStore();
    chat.dispose();
    contacts.dispose();
    await accountDataService.clearAll();
    chat.$reset();
    contacts.$reset();
    useSettingsStore().$reset();
    await useAuthStore().logout(false);
    await router.replace({ name: 'login' });
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '注销账号失败';
  } finally {
    submitting.value = false;
  }
};
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header"><button class="settings-back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'account-security' })">‹</button><div><p>账号与安全</p><h1>注销账号</h1></div></header>
    <section class="settings-content">
      <p v-if="error" class="settings-notice settings-notice--error">{{ error }}</p>
      <section class="settings-card deactivate-impact"><h2>注销后将永久删除</h2><p>账号资料与登录凭证</p><p>好友关系与群聊成员关系</p><p>服务端保存的聊天数据</p></section>
      <section class="settings-card">
        <label class="acknowledgement"><input v-model="acknowledged" type="checkbox" /><span>我已了解注销影响且数据无法恢复</span></label>
        <button v-if="!confirming" class="settings-danger rc-focus-ring" type="button" :disabled="!acknowledged" @click="confirming = true">注销账号</button>
        <template v-else>
          <label class="settings-field"><span>输入“注销”确认</span><input v-model="keyword" class="rc-focus-ring" autocomplete="off" placeholder="注销" /></label>
          <div class="confirm-actions"><button class="settings-danger rc-focus-ring" type="button" :disabled="keyword !== '注销' || submitting" @click="deactivate">{{ submitting ? '注销中...' : '确认注销' }}</button><button class="settings-secondary rc-focus-ring" type="button" :disabled="submitting" @click="confirming = false; keyword = ''">取消</button></div>
        </template>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.deactivate-impact h2, .deactivate-impact p { margin: 0; }
.deactivate-impact h2 { font-size: 16px; }
.deactivate-impact p { color: var(--rc-text-secondary); font-size: 14px; }
.deactivate-impact p::before { margin-right: 8px; color: var(--rc-danger); content: '−'; }
.acknowledgement { display: flex; align-items: center; gap: 10px; color: var(--rc-text-primary); font-size: 14px; }
.acknowledgement input { width: 18px; height: 18px; accent-color: var(--rc-primary); }
.settings-danger, .settings-secondary { min-height: 42px; border-radius: 8px; cursor: pointer; }
.settings-danger { background: var(--rc-danger); color: #fff; }
.settings-danger:disabled { cursor: not-allowed; opacity: .5; }
.settings-secondary { background: var(--rc-surface-muted); color: var(--rc-text-primary); }
.confirm-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
</style>
