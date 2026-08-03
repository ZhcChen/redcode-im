<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import { useChatStore } from '@/stores/chat';
import type { GroupInvitation, GroupInvitationStatus } from '@/types/room';

const router = useRouter();
const chatStore = useChatStore();
const invitations = ref<GroupInvitation[]>([]);
const filter = ref<'all' | 'pending'>('all');
const confirming = ref('');
const action = ref<'accepted' | 'declined' | ''>('');
const submitting = ref(false);
const loading = ref(false);
const error = ref('');
const notice = ref('');
const visibleInvitations = computed(() => invitations.value.filter((invitation) => (
  filter.value === 'all' || invitation.status === 'pending'
)).sort((a, b) => b.invitedAt.localeCompare(a.invitedAt)));

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    invitations.value = appEnv.useMockData ? createMockInvitations() : await roomService.listReceivedInvitations('all');
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载群邀请失败';
  } finally {
    loading.value = false;
  }
};

const beginRespond = (invitationId: string, nextAction: 'accepted' | 'declined') => {
  confirming.value = invitationId;
  action.value = nextAction;
};

const respond = async (invitation: GroupInvitation, status: 'accepted' | 'declined') => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      invitations.value = invitations.value.map((item) => item.id === invitation.id
        ? { ...item, status, respondedAt: new Date().toISOString() }
        : item);
    } else {
      await roomService.respondToInvitation(invitation.roomId, invitation.id, status);
      await load();
      if (status === 'accepted') await chatStore.refreshChats();
    }
    confirming.value = '';
    action.value = '';
    notice.value = status === 'accepted' ? '已加入群聊' : '已拒绝邀请';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '响应群邀请失败';
  } finally {
    submitting.value = false;
  }
};

const statusLabel = (status: GroupInvitationStatus) => ({
  pending: '待处理',
  accepted: '已接受',
  declined: '已拒绝',
  expired: '已过期',
}[status]);

onMounted(() => void load());

const createMockInvitations = (): GroupInvitation[] => [{
  id: 'mock-invitation',
  roomId: 'mock-room',
  roomName: '产品讨论群',
  roomAvatarUrl: null,
  inviterId: 'mock-inviter',
  inviterName: 'Mia',
  inviteeId: 'mock-current',
  message: '邀请你一起参与产品讨论',
  status: 'pending',
  invitedAt: new Date().toISOString(),
  respondedAt: null,
  expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
}];
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><h1>群通知</h1><p>{{ invitations.filter((item) => item.status === 'pending').length }} 条待处理</p></div>
      <button class="contact-page__action rc-focus-ring" type="button" :disabled="loading" @click="load">刷新</button>
    </header>
    <section class="contact-page__content">
      <div class="contact-page__tabs"><button type="button" :class="{ active: filter === 'all' }" @click="filter = 'all'">全部</button><button type="button" :class="{ active: filter === 'pending' }" @click="filter = 'pending'">待处理</button></div>
      <p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p>
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p>
      <p v-if="loading && invitations.length === 0" class="contact-page__empty">正在加载群通知...</p>
      <p v-else-if="visibleInvitations.length === 0" class="contact-page__empty">暂无群通知</p>
      <article v-for="invitation in visibleInvitations" :key="invitation.id" class="invitation-card" :data-invitation-id="invitation.id">
        <CachedAvatar kind="room" :entity-id="invitation.roomId" :label="invitation.roomName || '群聊邀请'" :size="46" />
        <div class="invitation-card__body">
          <div class="invitation-card__heading"><h2>{{ invitation.roomName || '群聊邀请' }}</h2><span :class="`status status--${invitation.status}`">{{ statusLabel(invitation.status) }}</span></div>
          <p>{{ invitation.inviterName || '群成员' }} 邀请你加入群聊</p>
          <p v-if="invitation.message" class="invitation-card__message">{{ invitation.message }}</p>
          <div v-if="invitation.status === 'pending' && confirming !== invitation.id" class="contact-page__actions"><button class="contact-page__primary rc-focus-ring" type="button" @click="beginRespond(invitation.id, 'accepted')">接受</button><button class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="beginRespond(invitation.id, 'declined')">拒绝</button></div>
          <div v-else-if="invitation.status === 'pending'" class="contact-page__actions"><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="respond(invitation, action as 'accepted' | 'declined')">确认{{ action === 'accepted' ? '接受' : '拒绝' }}</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirming = ''; action = ''">取消</button></div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.invitation-card { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 12px; border-radius: 8px; background: var(--rc-surface); padding: 14px; }
.invitation-card__body { display: grid; gap: 7px; min-width: 0; }
.invitation-card__heading { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.invitation-card h2, .invitation-card p { margin: 0; }
.invitation-card h2 { font-size: 16px; }
.invitation-card p { color: var(--rc-text-secondary); line-height: 1.5; }
.invitation-card__message { border-radius: 6px; background: var(--rc-surface-muted); padding: 8px 10px; font-size: 12px; }
.status { flex: 0 0 auto; border-radius: 999px; padding: 3px 8px; font-size: 11px; }
.status--pending { background: #fff4d6; color: #9a6700; }
.status--accepted { background: #e7f7ed; color: #137333; }
.status--declined, .status--expired { background: var(--rc-surface-muted); color: var(--rc-text-tertiary); }
</style>
