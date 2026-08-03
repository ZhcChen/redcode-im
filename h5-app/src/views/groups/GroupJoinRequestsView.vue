<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import { useAuthStore } from '@/stores/auth';
import { useGroupSettingsStore } from '@/stores/group-settings';
import type { GroupJoinRequest, JoinRequestStatus } from '@/types/room';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const group = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const requests = ref<GroupJoinRequest[]>([]);
const reviewMessages = reactive<Record<string, string>>({});
const confirming = ref('');
const action = ref<'approved' | 'rejected' | ''>('');
const submitting = ref(false);
const error = ref('');
const notice = ref('');
const approvalEnabled = ref(false);
const myRole = computed(() => group.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const sortedRequests = computed(() => requests.value.slice().sort((a, b) => {
  if (a.status === 'pending' && b.status !== 'pending') return -1;
  if (a.status !== 'pending' && b.status === 'pending') return 1;
  return b.createdAt.localeCompare(a.createdAt);
}));
const pendingCount = computed(() => requests.value.filter((request) => request.status === 'pending').length);

const loadRequests = async () => {
  if (appEnv.useMockData) {
    if (requests.value.length === 0) {
      requests.value = [{
        id: 'mock-join-request',
        roomId: roomId.value,
        applicantId: 'mock-applicant',
        message: '希望加入群聊参与讨论',
        status: 'pending',
        reviewerId: null,
        reviewMessage: null,
        createdAt: new Date().toISOString(),
        reviewedAt: null,
      }];
    }
    return;
  }
  requests.value = await roomService.listJoinRequests(roomId.value);
};

const beginReview = (requestId: string, nextAction: 'approved' | 'rejected') => {
  confirming.value = requestId;
  action.value = nextAction;
};

const review = async (requestId: string, status: Exclude<JoinRequestStatus, 'pending'>) => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      requests.value = requests.value.map((request) => request.id === requestId ? {
        ...request,
        status,
        reviewerId: auth.currentUser?.id ?? '',
        reviewMessage: reviewMessages[requestId]?.trim() || null,
        reviewedAt: new Date().toISOString(),
      } : request);
    } else {
      await roomService.reviewJoinRequest(roomId.value, requestId, status, reviewMessages[requestId]);
      await loadRequests();
    }
    confirming.value = '';
    action.value = '';
    notice.value = status === 'approved' ? '已通过入群申请' : '已拒绝入群申请';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '审核入群申请失败';
  } finally {
    submitting.value = false;
  }
};

const saveApprovalSetting = async () => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      if (group.settings) group.settings.joinApprovalRequired = approvalEnabled.value;
    } else {
      group.settings = await roomService.updateJoinApproval(roomId.value, approvalEnabled.value);
    }
    notice.value = approvalEnabled.value ? '入群审核已开启' : '入群审核已关闭';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '更新入群审核设置失败';
  } finally {
    submitting.value = false;
  }
};

const statusLabel = (status: JoinRequestStatus) => ({
  pending: '待审核',
  approved: '已通过',
  rejected: '已拒绝',
}[status]);
const applicantLabel = (applicantId: string) => `${applicantId.slice(0, 8)}...${applicantId.slice(-4)}`;

onMounted(async () => {
  await group.enterRoom(roomId.value);
  approvalEnabled.value = Boolean(group.settings?.joinApprovalRequired);
  if (!canManage.value) return;
  try {
    await loadRequests();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载入群申请失败';
  }
});
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button>
      <div><h1>入群审核</h1><p>{{ canManage ? `${pendingCount} 条待处理` : '仅群主和管理员可操作' }}</p></div>
    </header>
    <section class="contact-page__content">
      <p v-if="error || group.error" class="contact-page__notice contact-page__notice--error">{{ error || group.error }}</p>
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p>
      <p v-if="!group.loading && !canManage" class="contact-page__empty">你没有审核入群申请的权限</p>
      <form v-else-if="!group.loading" class="approval-panel" @submit.prevent="saveApprovalSetting">
        <div><h2>入群需要审核</h2><p>开启后，新成员需通过审核才能加入群聊</p></div>
        <input v-model="approvalEnabled" type="checkbox" aria-label="开启入群审核" />
        <button class="contact-page__primary rc-focus-ring" type="submit" :disabled="submitting">保存审核设置</button>
      </form>
      <p v-if="!group.loading && canManage && sortedRequests.length === 0" class="contact-page__empty">暂无入群申请</p>
      <article v-for="request in sortedRequests" :key="request.id" class="join-request-card" :data-applicant-id="request.applicantId">
        <CachedAvatar kind="user" :entity-id="request.applicantId" :label="request.applicantId" :size="44" />
        <div class="join-request-card__body">
          <div class="join-request-card__heading"><h2>用户 {{ applicantLabel(request.applicantId) }}</h2><span :class="`status status--${request.status}`">{{ statusLabel(request.status) }}</span></div>
          <p>{{ request.message || '未填写申请理由' }}</p>
          <p v-if="request.reviewMessage" class="join-request-card__review">审核备注：{{ request.reviewMessage }}</p>
          <template v-if="request.status === 'pending'">
            <input v-model="reviewMessages[request.id]" class="join-request-card__input rc-focus-ring" maxlength="100" placeholder="填写审核备注（可选）" />
            <div v-if="confirming !== request.id" class="contact-page__actions"><button class="contact-page__primary rc-focus-ring" type="button" @click="beginReview(request.id, 'approved')">通过</button><button class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="beginReview(request.id, 'rejected')">拒绝</button></div>
            <div v-else class="contact-page__actions"><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="review(request.id, action as 'approved' | 'rejected')">确认{{ action === 'approved' ? '通过' : '拒绝' }}</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirming = ''; action = ''">取消</button></div>
          </template>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.join-request-card { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 12px; border-radius: 8px; background: var(--rc-surface); padding: 14px; }
.join-request-card__body { display: grid; gap: 9px; min-width: 0; }
.join-request-card__heading { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.join-request-card h2, .join-request-card p { margin: 0; }
.join-request-card h2 { font-size: 15px; }
.join-request-card p { color: var(--rc-text-secondary); line-height: 1.5; }
.join-request-card__review { font-size: 12px; }
.join-request-card__input { width: 100%; height: 40px; border: 0; border-radius: 8px; background: var(--rc-surface-muted); padding: 0 12px; }
.status { flex: 0 0 auto; border-radius: 999px; padding: 3px 8px; font-size: 11px; }
.status--pending { background: #fff4d6; color: #9a6700; }
.status--approved { background: #e7f7ed; color: #137333; }
.status--rejected { background: #feeceb; color: var(--rc-danger); }
.approval-panel { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 12px; border-radius: 8px; background: var(--rc-surface); padding: 14px; }
.approval-panel h2, .approval-panel p { margin: 0; }
.approval-panel h2 { font-size: 16px; }
.approval-panel p { margin-top: 4px; color: var(--rc-text-tertiary); font-size: 12px; }
.approval-panel .contact-page__primary { grid-column: 1 / -1; justify-self: start; }
</style>
