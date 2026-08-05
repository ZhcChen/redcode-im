<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { e2eeDeviceManager } from '@/e2ee/device-manager';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import { useAuthStore } from '@/stores/auth';
import type { E2eeDeviceInfo } from '@/services/e2ee-mls-api-service';
import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const store = useSettingsStore();
const authStore = useAuthStore();
const devices = ref<E2eeDeviceInfo[]>([]);
const currentDeviceId = ref('');
const deviceBusy = ref('');
const deviceError = ref('');
const loadingDevices = ref(false);

const goBack = async () => {
  await router.push({ name: 'settings' });
};

onMounted(() => {
  void store.initialize();
  void refreshDevices();
});

const refreshDevices = async () => {
  const accountId = authStore.currentUser?.id ?? '';
  if (!accountId) return;
  loadingDevices.value = true;
  deviceError.value = '';
  try {
    const profile = await e2eeSecureStateStorage.readDeviceProfile(accountId);
    currentDeviceId.value = profile?.deviceId ?? '';
    devices.value = await e2eeDeviceManager.listDevices();
  } catch (error) {
    deviceError.value = error instanceof Error ? error.message : '设备列表加载失败';
  } finally {
    loadingDevices.value = false;
  }
};

const approveDevice = async (device: E2eeDeviceInfo) => {
  const accountId = authStore.currentUser?.id ?? '';
  if (!accountId) return;
  deviceBusy.value = device.id;
  deviceError.value = '';
  try {
    await e2eeDeviceManager.approveDevice(accountId, device);
    await refreshDevices();
  } catch (error) {
    deviceError.value = error instanceof Error ? error.message : '设备批准失败';
  } finally {
    deviceBusy.value = '';
  }
};

const revokeDevice = async (device: E2eeDeviceInfo) => {
  deviceBusy.value = device.id;
  deviceError.value = '';
  try {
    await e2eeDeviceManager.revokeDevice(device.id);
    await refreshDevices();
  } catch (error) {
    deviceError.value = error instanceof Error ? error.message : '设备撤销失败';
  } finally {
    deviceBusy.value = '';
  }
};
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>账号与安全</p>
        <h1>{{ store.user?.email || 'RedCode 用户' }}</h1>
      </div>
    </header>

    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <p v-if="store.notice" class="settings-notice">{{ store.notice }}</p>

      <form class="settings-card" @submit.prevent="store.changePassword">
        <label class="settings-field">
          <span>当前密码</span>
          <input v-model="store.oldPassword" class="rc-focus-ring" type="password" autocomplete="current-password" />
        </label>
        <label class="settings-field">
          <span>新密码</span>
          <input v-model="store.newPassword" class="rc-focus-ring" type="password" autocomplete="new-password" />
        </label>
        <button
          class="settings-primary rc-focus-ring"
          type="submit"
          :disabled="store.submitting || !store.oldPassword || !store.newPassword"
        >
          修改密码
        </button>
      </form>
      <section class="settings-card">
        <h2 class="settings-section-title">E2EE 设备</h2>
        <p v-if="deviceError" class="settings-notice settings-notice--error">{{ deviceError }}</p>
        <p v-if="loadingDevices" class="settings-notice">正在加载设备…</p>
        <ul v-if="!loadingDevices && devices.length" class="device-list">
          <li v-for="device in devices" :key="device.id" class="device-row">
            <div class="device-info">
              <strong>{{ device.deviceLabel || '未命名设备' }}</strong>
              <span>
                {{
                  device.status === 'active'
                    ? (device.id === currentDeviceId ? '当前设备' : '已批准')
                    : device.status === 'pending_approval' ? '等待批准' : '已撤销'
                }}
              </span>
            </div>
            <button
              v-if="device.status === 'pending_approval'"
              class="settings-primary rc-focus-ring"
              type="button"
              :disabled="Boolean(deviceBusy)"
              @click="approveDevice(device)"
            >
              {{ deviceBusy === device.id ? '批准中…' : '批准' }}
            </button>
            <button
              v-else-if="device.status === 'active' && device.id !== currentDeviceId"
              class="settings-danger rc-focus-ring"
              type="button"
              :disabled="Boolean(deviceBusy)"
              @click="revokeDevice(device)"
            >
              {{ deviceBusy === device.id ? '撤销中…' : '撤销' }}
            </button>
          </li>
        </ul>
        <p v-if="!loadingDevices && !devices.length" class="settings-notice">
          暂无 E2EE 设备，进入加密会话后会自动登记。
        </p>
      </section>
      <section class="settings-card">
        <button class="settings-danger rc-focus-ring" type="button" @click="router.push({ name: 'settings-deactivate' })">注销账号</button>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.settings-danger { min-height: 42px; border-radius: 8px; cursor: pointer; background: transparent; color: var(--rc-danger); font-weight: 700; }
.settings-section-title { margin: 0 0 12px; font-size: 14px; color: var(--rc-text-secondary, #666); }
.device-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
.device-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.device-info { display: grid; gap: 2px; min-width: 0; }
.device-info span { font-size: 12px; color: var(--rc-text-secondary, #666); }
.device-row .settings-primary,
.device-row .settings-danger { min-height: 32px; flex: none; }
</style>
