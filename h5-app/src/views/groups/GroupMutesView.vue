<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import { useAuthStore } from '@/stores/auth';
import { useGroupSettingsStore } from '@/stores/group-settings';
import type { GroupMute } from '@/types/room';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const group = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const mutes = ref<GroupMute[]>([]);
const selectedUserId = ref('');
const durationHours = ref(24);
const memberReason = ref('');
const globalEnabled = ref(false);
const globalDurationMinutes = ref(0);
const globalReason = ref('');
const confirmingUnmute = ref('');
const submitting = ref(false);
const error = ref('');
const notice = ref('');
const myRole = computed(() => group.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const activeMutes = computed(() => mutes.value.filter((mute) => mute.isActive));
const mutedIds = computed(() => new Set(activeMutes.value.map((mute) => mute.userId)));
const candidates = computed(() => group.members.filter((member) => (
  member.role === 'member' && member.userId !== auth.currentUser?.id && !mutedIds.value.has(member.userId)
)));
const selectedMember = computed(() => group.members.find((member) => member.userId === selectedUserId.value));

const loadMutes = async () => {
  mutes.value = appEnv.useMockData ? mutes.value : await roomService.listMutes(roomId.value);
};

const saveGlobalMute = async () => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      if (group.settings) group.settings.globalMuteEnabled = globalEnabled.value;
    } else {
      group.settings = await roomService.updateGlobalMute(roomId.value, {
        enabled: globalEnabled.value,
        reason: globalReason.value,
        durationMinutes: globalEnabled.value ? globalDurationMinutes.value : undefined,
      });
    }
    notice.value = globalEnabled.value ? '全体禁言已开启' : '全体禁言已关闭';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '更新全体禁言失败';
  } finally {
    submitting.value = false;
  }
};

const muteSelected = async () => {
  if (!selectedUserId.value) return;
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      mutes.value.push({
        id: `mock-mute-${Date.now()}`,
        roomId: roomId.value,
        userId: selectedUserId.value,
        mutedBy: auth.currentUser?.id ?? '',
        reason: memberReason.value.trim() || null,
        muteDurationHours: durationHours.value,
        mutedAt: new Date().toISOString(),
        unmutedAt: null,
        isActive: true,
      });
    } else {
      await roomService.muteUser(roomId.value, {
        userId: selectedUserId.value,
        durationHours: durationHours.value,
        reason: memberReason.value,
      });
      await loadMutes();
    }
    selectedUserId.value = '';
    memberReason.value = '';
    notice.value = '成员已禁言';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '禁言成员失败';
  } finally {
    submitting.value = false;
  }
};

const unmute = async (userId: string) => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      mutes.value = mutes.value.map((mute) => mute.userId === userId ? { ...mute, isActive: false } : mute);
    } else {
      await roomService.unmuteUser(roomId.value, userId);
      await loadMutes();
    }
    confirmingUnmute.value = '';
    notice.value = '成员已解除禁言';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '解除禁言失败';
  } finally {
    submitting.value = false;
  }
};

const memberName = (userId: string) => {
  const member = group.members.find((item) => item.userId === userId);
  return member?.nickname || member?.username || '群成员';
};

const muteDurationLabel = (mute: GroupMute) => mute.muteDurationHours === 0 ? '永久禁言' : `${mute.muteDurationHours} 小时`;

onMounted(async () => {
  await group.enterRoom(roomId.value);
  globalEnabled.value = Boolean(group.settings?.globalMuteEnabled);
  globalReason.value = group.settings?.globalMuteReason ?? '';
  if (!canManage.value) return;
  try {
    await loadMutes();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载禁言列表失败';
  }
});
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button>
      <div><h1>禁言管理</h1><p>{{ canManage ? `${activeMutes.length} 位成员被禁言` : '仅群主和管理员可操作' }}</p></div>
    </header>
    <section class="contact-page__content">
      <p v-if="error || group.error" class="contact-page__notice contact-page__notice--error">{{ error || group.error }}</p>
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p>
      <p v-if="!group.loading && !canManage" class="contact-page__empty">你没有管理群禁言的权限</p>
      <template v-else-if="!group.loading">
        <form class="mute-panel" @submit.prevent="saveGlobalMute">
          <div class="mute-panel__heading"><div><h2>全体禁言</h2><p>群主和管理员仍可发送消息</p></div><input v-model="globalEnabled" type="checkbox" aria-label="开启全体禁言" /></div>
          <template v-if="globalEnabled">
            <label class="contact-page__field">持续时间<select v-model.number="globalDurationMinutes" class="rc-focus-ring"><option :value="0">永久</option><option :value="60">1 小时</option><option :value="360">6 小时</option><option :value="1440">1 天</option><option :value="10080">7 天</option></select></label>
            <label class="contact-page__field">原因（可选）<input v-model="globalReason" class="rc-focus-ring" maxlength="100" placeholder="填写全体禁言原因" /></label>
          </template>
          <button class="contact-page__primary rc-focus-ring" type="submit" :disabled="submitting">保存全体禁言</button>
        </form>

        <section class="mute-panel">
          <h2>禁言成员</h2>
          <label class="contact-page__field">选择普通成员<select v-model="selectedUserId" class="rc-focus-ring"><option value="">请选择成员</option><option v-for="member in candidates" :key="member.userId" :value="member.userId">{{ member.nickname || member.username }}</option></select></label>
          <template v-if="selectedMember">
            <label class="contact-page__field">禁言时长<select v-model.number="durationHours" class="rc-focus-ring"><option :value="1">1 小时</option><option :value="6">6 小时</option><option :value="24">1 天</option><option :value="72">3 天</option><option :value="168">7 天</option><option :value="0">永久</option></select></label>
            <label class="contact-page__field">原因（可选）<input v-model="memberReason" class="rc-focus-ring" maxlength="100" placeholder="填写成员禁言原因" /></label>
            <button class="contact-page__primary rc-focus-ring" type="button" :disabled="submitting" @click="muteSelected">确认禁言</button>
          </template>
          <p v-else-if="candidates.length === 0" class="contact-page__empty">暂无可禁言的普通成员</p>
        </section>

        <h2 class="contact-page__section-title">当前禁言成员</h2>
        <p v-if="activeMutes.length === 0" class="contact-page__empty">暂无被禁言的成员</p>
        <article v-for="mute in activeMutes" :key="mute.id" class="contact-page__row">
          <CachedAvatar kind="user" :entity-id="mute.userId" :label="memberName(mute.userId)" :size="42" />
          <div><h2>{{ memberName(mute.userId) }}</h2><p>{{ muteDurationLabel(mute) }}{{ mute.reason ? ` · ${mute.reason}` : '' }}</p></div>
          <button v-if="confirmingUnmute !== mute.userId" class="contact-page__action rc-focus-ring" type="button" @click="confirmingUnmute = mute.userId">解除禁言</button>
          <div v-else class="contact-page__actions"><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="unmute(mute.userId)">确认解除</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirmingUnmute = ''">取消</button></div>
        </article>
      </template>
    </section>
  </main>
</template>

<style scoped>
.mute-panel { display: grid; gap: 12px; border-radius: 8px; background: var(--rc-surface); padding: 14px; }
.mute-panel h2, .mute-panel p { margin: 0; }
.mute-panel h2 { font-size: 16px; }
.mute-panel__heading { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.mute-panel__heading p { margin-top: 4px; color: var(--rc-text-tertiary); font-size: 12px; }
.mute-panel select { width: 100%; height: 44px; border: 0; border-radius: 8px; background: var(--rc-surface-muted); color: var(--rc-text-primary); padding: 0 12px; }
.contact-page__section-title { margin: 4px 2px 0; color: var(--rc-text-secondary); font-size: 13px; }
</style>
