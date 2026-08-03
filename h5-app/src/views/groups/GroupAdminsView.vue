<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import { useAuthStore } from '@/stores/auth';
import { useGroupSettingsStore } from '@/stores/group-settings';
import type { GroupAdmin } from '@/types/room';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const group = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const admins = ref<GroupAdmin[]>([]);
const confirming = ref('');
const action = ref<'appoint' | 'remove' | ''>('');
const submitting = ref(false);
const error = ref('');
const notice = ref('');
const myRole = computed(() => group.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const isOwner = computed(() => myRole.value === 'owner');
const adminIds = computed(() => new Set(admins.value.map((admin) => admin.adminId)));
const candidates = computed(() => group.members.filter((member) => (
  member.role !== 'owner' && member.role !== 'admin' && !adminIds.value.has(member.userId)
)));
const adminMembers = computed(() => admins.value.map((admin) => ({
  admin,
  member: group.members.find((member) => member.userId === admin.adminId),
})));

const loadAdmins = async () => {
  if (appEnv.useMockData) {
    admins.value = group.members.filter((member) => member.role === 'admin').map((member) => ({
      id: `mock-admin-${member.userId}`,
      roomId: roomId.value,
      adminId: member.userId,
      appointedBy: group.room?.ownerId ?? 'mock-current',
      role: 'admin',
      permissions: [],
      appointedAt: new Date().toISOString(),
    }));
    return;
  }
  admins.value = await roomService.listAdmins(roomId.value);
};

const appoint = async (userId: string) => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      const member = group.members.find((item) => item.userId === userId);
      if (member) member.role = 'admin';
    } else {
      await roomService.appointAdmin(roomId.value, userId);
      await group.enterRoom(roomId.value);
    }
    await loadAdmins();
    confirming.value = '';
    action.value = '';
    notice.value = '管理员已任命';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '任命管理员失败';
  } finally {
    submitting.value = false;
  }
};

const remove = async (userId: string) => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      const member = group.members.find((item) => item.userId === userId);
      if (member) member.role = 'member';
    } else {
      await roomService.removeAdmin(roomId.value, userId);
      await group.enterRoom(roomId.value);
    }
    await loadAdmins();
    confirming.value = '';
    action.value = '';
    notice.value = '管理员身份已撤销';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '撤销管理员失败';
  } finally {
    submitting.value = false;
  }
};

const beginConfirm = (nextAction: 'appoint' | 'remove', userId: string) => {
  action.value = nextAction;
  confirming.value = userId;
};

onMounted(async () => {
  await group.enterRoom(roomId.value);
  if (isOwner.value) {
    try {
      await loadAdmins();
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : '加载管理员失败';
    }
  }
});
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button>
      <div><h1>管理员设置</h1><p>{{ isOwner ? `${admins.length} 位管理员` : '仅群主可操作' }}</p></div>
    </header>
    <section class="contact-page__content">
      <p v-if="error || group.error" class="contact-page__notice contact-page__notice--error">{{ error || group.error }}</p>
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p>
      <p v-if="!group.loading && !isOwner" class="contact-page__empty">你没有管理群管理员的权限</p>
      <template v-else-if="!group.loading">
        <h2 class="contact-page__section-title">当前管理员</h2>
        <p v-if="adminMembers.length === 0" class="contact-page__empty">暂无管理员</p>
        <article v-for="item in adminMembers" :key="item.admin.id" class="contact-page__row">
          <CachedAvatar kind="user" :entity-id="item.admin.adminId" :label="item.member?.nickname || item.member?.username || '群管理员'" :size="42" />
          <div><h2>{{ item.member?.nickname || item.member?.username || '群管理员' }}</h2><p>{{ item.member?.username || '管理员' }}</p></div>
          <button v-if="confirming !== item.admin.adminId || action !== 'remove'" class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="beginConfirm('remove', item.admin.adminId)">撤销</button>
          <div v-else class="contact-page__actions"><button class="contact-page__action contact-page__danger rc-focus-ring" type="button" :disabled="submitting" @click="remove(item.admin.adminId)">确认</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirming = ''; action = ''">取消</button></div>
        </article>

        <h2 class="contact-page__section-title">任命新管理员</h2>
        <p v-if="candidates.length === 0" class="contact-page__empty">暂无可任命的普通成员</p>
        <article v-for="member in candidates" :key="member.userId" class="contact-page__row">
          <CachedAvatar kind="user" :entity-id="member.userId" :label="member.nickname || member.username || '群成员'" :size="42" />
          <div><h2>{{ member.nickname || member.username || '群成员' }}</h2><p>{{ member.username }}</p></div>
          <button v-if="confirming !== member.userId || action !== 'appoint'" class="contact-page__action rc-focus-ring" type="button" @click="beginConfirm('appoint', member.userId)">设为管理员</button>
          <div v-else class="contact-page__actions"><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="appoint(member.userId)">确认</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirming = ''; action = ''">取消</button></div>
        </article>
      </template>
    </section>
  </main>
</template>

<style scoped>
.contact-page__section-title { margin: 4px 2px 0; color: var(--rc-text-secondary); font-size: 13px; }
</style>
