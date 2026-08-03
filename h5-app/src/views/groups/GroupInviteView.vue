<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { displayName } from '@/storage/contact-storage';
import { roomService } from '@/services/room-service';
import { useAuthStore } from '@/stores/auth';
import { useContactsStore } from '@/stores/contacts';
import { useGroupSettingsStore } from '@/stores/group-settings';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const contacts = useContactsStore();
const group = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const selected = ref<string[]>([]);
const notice = ref('');
const error = ref('');
const submitting = ref(false);
const myRole = computed(() => group.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const candidates = computed(() => {
  if (!canManage.value) return [];
  const memberIds = new Set(group.members.map((member) => member.userId));
  return contacts.friends.filter((friend) => !memberIds.has(friend.user.id));
});
const toggle = (id: string) => {
  selected.value = selected.value.includes(id)
    ? selected.value.filter((item) => item !== id)
    : [...selected.value, id];
};
const submit = async () => {
  submitting.value = true;
  notice.value = '';
  error.value = '';
  try {
    const result = await roomService.addMembers(roomId.value, selected.value);
    notice.value = `已添加 ${result.addedUserIds.length} 人`;
    selected.value = [];
    await group.enterRoom(roomId.value);
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '添加群成员失败';
  } finally {
    submitting.value = false;
  }
};
onMounted(async () => {
  await Promise.all([contacts.initialize(), group.enterRoom(roomId.value)]);
});
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header"><button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-members', params: { roomId } })">‹</button><div><h1>邀请联系人</h1><p>{{ canManage ? `已选择 ${selected.length} 人` : '仅群主和管理员可操作' }}</p></div><button v-if="canManage" class="contact-page__primary rc-focus-ring" type="button" :disabled="selected.length === 0 || submitting" @click="submit">{{ submitting ? '添加中' : '添加' }}</button></header>
    <section class="contact-page__content">
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p><p v-if="error || group.error || contacts.error" class="contact-page__notice contact-page__notice--error">{{ error || group.error || contacts.error }}</p>
      <p v-if="!group.loading && !canManage" class="contact-page__empty">你没有邀请群成员的权限</p>
      <p v-else-if="!group.loading && candidates.length === 0" class="contact-page__empty">所有联系人都已在群聊中</p>
      <button v-for="friend in candidates" :key="friend.user.id" class="contact-page__row rc-focus-ring" type="button" @click="toggle(friend.user.id)"><CachedAvatar kind="user" :entity-id="friend.user.id" :label="displayName(friend)" :size="42" /><span><h2>{{ displayName(friend) }}</h2><p>{{ friend.user.username }}</p></span><input type="checkbox" tabindex="-1" aria-hidden="true" :checked="selected.includes(friend.user.id)" /></button>
    </section>
  </main>
</template>
