<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useGroupSettingsStore } from '@/stores/group-settings';
import { useAuthStore } from '@/stores/auth';

const route = useRoute();
const router = useRouter();
const store = useGroupSettingsStore();
const authStore = useAuthStore();
const avatarInput = ref<HTMLInputElement | null>(null);

const roomId = computed(() => String(route.params.roomId ?? ''));
const owner = computed(() => store.members.find((member) => member.role === 'owner'));
const myRole = computed(() => store.members.find((member) => member.userId === authStore.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const isOwner = computed(() => myRole.value === 'owner');

const goBack = async () => {
  await router.push({ name: 'chat-detail', params: { roomId: roomId.value } });
};

const leaveRoom = async () => {
  await store.leaveRoom();
  await router.replace({ name: 'home' });
};

const dissolveRoom = async () => {
  await store.dissolveRoom();
  await router.replace({ name: 'home' });
};

const chooseRoomAvatar = () => {
  avatarInput.value?.click();
};

const handleRoomAvatarSelected = async (event: Event) => {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0] ?? null;
  input.value = '';
  try {
    await store.uploadRoomAvatar(file);
  } catch {
    // Store state already contains the user-facing error.
  }
};

onMounted(() => {
  void store.enterRoom(roomId.value);
});
</script>

<template>
  <main class="group-settings app-phone-frame">
    <header class="group-settings__header">
      <button class="group-settings__back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>群聊设置</p>
        <h1>{{ store.room?.name || '群聊' }}</h1>
      </div>
    </header>

    <section class="group-settings__content">
      <p v-if="store.error" class="group-settings__notice group-settings__notice--error">{{ store.error }}</p>
      <p v-if="store.notice" class="group-settings__notice">{{ store.notice }}</p>
      <p v-if="store.loading" class="group-settings__notice">正在加载群设置...</p>

      <section class="settings-panel">
        <h2>基础信息</h2>
        <div class="room-avatar-panel">
          <CachedAvatar
            class="room-avatar-panel__avatar"
            kind="room"
            :entity-id="roomId"
            :object-key="store.room?.avatarObjectKey"
            :label="store.room?.name || '群聊'"
            :size="72"
          />
          <div>
            <input ref="avatarInput" class="sr-only" type="file" accept="image/*" @change="handleRoomAvatarSelected" />
            <button v-if="canManage" class="avatar-upload-button rc-focus-ring" type="button" :disabled="store.avatarUploading" @click="chooseRoomAvatar">
              {{ store.avatarUploading ? '上传中...' : '更换群头像' }}
            </button>
            <p class="settings-hint">上传失败会保留当前群头像。</p>
          </div>
        </div>
        <label class="settings-field">
          <span>群名称</span>
          <input v-model="store.draftName" class="rc-focus-ring" placeholder="输入群名称" :disabled="!canManage" />
        </label>
        <button v-if="canManage" class="settings-action rc-focus-ring" type="button" :disabled="store.submitting" @click="store.updateName">
          保存群名称
        </button>
      </section>

      <section class="settings-panel">
        <div class="settings-panel__title">
          <h2>成员</h2>
          <span>{{ store.members.length }} 人</span>
        </div>
        <div class="member-grid">
          <article v-for="member in store.members" :key="member.userId" class="member-card">
            <CachedAvatar
              class="member-card__avatar"
              kind="user"
              :entity-id="member.userId"
              :label="member.nickname || member.username || 'RedCode 用户'"
              :size="38"
            />
            <div>
              <h3>{{ member.nickname || member.username || 'RedCode 用户' }}</h3>
              <p>{{ member.role || 'member' }}</p>
            </div>
          </article>
        </div>
        <p v-if="owner" class="settings-hint">群主：{{ owner.nickname || owner.username }}</p>
        <button class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'group-members', params: { roomId } })"><span>查看全部成员</span><strong>›</strong></button>
        <button v-if="canManage" class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'group-invite', params: { roomId } })"><span>邀请联系人</span><strong>›</strong></button>
      </section>

      <section class="settings-panel">
        <button v-if="isOwner" class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'group-admins', params: { roomId } })">
          <span>管理员设置</span>
          <strong>›</strong>
        </button>
        <button class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'group-rules', params: { roomId } })">
          <span>群规</span>
          <strong>›</strong>
        </button>
        <button v-if="canManage" class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'group-mutes', params: { roomId } })">
          <span>禁言管理</span>
          <strong>›</strong>
        </button>
        <button class="settings-row rc-focus-ring" type="button" @click="store.togglePinned">
          <span>置顶聊天</span>
          <strong>{{ store.pinned ? '已开启' : '未开启' }}</strong>
        </button>
        <button class="settings-row rc-focus-ring" type="button" @click="store.toggleMuted">
          <span>消息免打扰</span>
          <strong>{{ store.muted ? '已开启' : '未开启' }}</strong>
        </button>
      </section>

      <section class="settings-panel">
        <button v-if="!isOwner" class="danger-action rc-focus-ring" type="button" :disabled="store.submitting" @click="leaveRoom">
          退出群聊
        </button>
        <button v-if="isOwner" class="danger-action danger-action--solid rc-focus-ring" type="button" :disabled="store.submitting" @click="dissolveRoom">
          解散群聊
        </button>
      </section>
    </section>
  </main>
</template>

<style scoped>
.group-settings {
  min-height: 100dvh;
  background: var(--rc-background);
}

.group-settings__header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: calc(var(--rc-safe-top) + 10px) 16px 14px;
  background: var(--rc-surface);
  box-shadow: 0 1px 0 var(--rc-divider);
}

.group-settings__back {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 34px;
  line-height: 1;
}

.group-settings__header p,
.settings-hint {
  margin: 0;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.group-settings__header h1 {
  margin: 3px 0 0;
  color: var(--rc-text-primary);
  font-size: 19px;
}

.group-settings__content {
  display: grid;
  gap: 12px;
  padding: 16px;
}

.group-settings__notice {
  margin: 0;
  border-radius: 14px;
  background: var(--rc-surface);
  color: var(--rc-text-secondary);
  font-size: 13px;
  padding: 12px;
}

.group-settings__notice--error {
  background: #feeceb;
  color: var(--rc-danger);
}

.settings-panel {
  display: grid;
  gap: 12px;
  border-radius: 20px;
  background: var(--rc-surface);
  padding: 16px;
}

.settings-panel h2 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 16px;
}

.room-avatar-panel {
  display: flex;
  align-items: center;
  gap: 14px;
}

.room-avatar-panel__avatar {
  display: grid;
  place-items: center;
  width: 72px;
  height: 72px;
  border-radius: 20px;
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-size: 24px;
  font-weight: 800;
}

.avatar-upload-button {
  min-width: 116px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.avatar-upload-button:disabled {
  cursor: not-allowed;
  opacity: 0.58;
}

.settings-panel__title {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.settings-panel__title span {
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.settings-field {
  display: grid;
  gap: 8px;
  color: var(--rc-text-secondary);
  font-size: 13px;
}

.settings-field input {
  height: 42px;
  border: 0;
  border-radius: 14px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 12px;
}

.settings-action,
.danger-action {
  height: 42px;
  border-radius: 14px;
  cursor: pointer;
  font-weight: 700;
}

.settings-action {
  background: var(--rc-primary);
  color: #fff;
}

.settings-action:disabled,
.danger-action:disabled {
  cursor: not-allowed;
  opacity: 0.58;
}

.member-grid {
  display: grid;
  gap: 10px;
}

.member-card {
  display: flex;
  align-items: center;
  gap: 10px;
}

.member-card__avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-weight: 700;
}

.member-card h3 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 14px;
}

.member-card p {
  margin: 3px 0 0;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.settings-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 44px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 15px;
}

.settings-row strong {
  color: var(--rc-text-tertiary);
  font-size: 13px;
}

.danger-action {
  background: #feeceb;
  color: var(--rc-danger);
}

.danger-action--solid {
  background: var(--rc-danger);
  color: #fff;
}
</style>
