<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useAuthStore } from '@/stores/auth';
import { useGroupSettingsStore } from '@/stores/group-settings';
import { roomService } from '@/services/room-service';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const store = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const keyword = ref('');
const confirming = ref('');
const removing = ref('');
const actionError = ref('');
const myRole = computed(() => store.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const members = computed(() => {
  const query = keyword.value.trim().toLowerCase();
  if (!query) return store.members;
  return store.members.filter((member) => (
    [member.nickname, member.username].some((value) => String(value ?? '').toLowerCase().includes(query))
  ));
});
const canRemove = (role?: string | null) => canManage.value && role !== 'owner' && (myRole.value === 'owner' || role !== 'admin');
const remove = async (userId: string) => {
  removing.value = userId;
  actionError.value = '';
  try {
    await roomService.removeMember(roomId.value, userId);
    confirming.value = '';
    await store.enterRoom(roomId.value);
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : '移除群成员失败';
  } finally {
    removing.value = '';
  }
};
onMounted(() => void store.enterRoom(roomId.value));
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header"><button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button><div><h1>群成员</h1><p>{{ store.members.length }} 人</p></div><button v-if="canManage" class="contact-page__primary rc-focus-ring" type="button" @click="router.push({ name: 'group-invite', params: { roomId } })">邀请</button></header>
    <section class="contact-page__content">
      <label class="contact-page__search"><input v-model="keyword" class="rc-focus-ring" placeholder="搜索群成员" /></label>
      <p v-if="store.error || actionError" class="contact-page__notice contact-page__notice--error">{{ actionError || store.error }}</p>
      <article v-for="member in members" :key="member.userId" class="contact-page__row">
        <CachedAvatar kind="user" :entity-id="member.userId" :label="member.nickname || member.username" :size="42" />
        <div><h2>{{ member.nickname || member.username }}</h2><p>{{ member.role === 'owner' ? '群主' : member.role === 'admin' ? '管理员' : member.username }}</p></div>
        <template v-if="canRemove(member.role) && member.userId !== auth.currentUser?.id">
          <button v-if="confirming !== member.userId" class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="confirming = member.userId">移除</button>
          <div v-else class="contact-page__actions"><button class="contact-page__action contact-page__danger rc-focus-ring" type="button" :disabled="removing === member.userId" @click="remove(member.userId)">{{ removing === member.userId ? '移除中' : '确认' }}</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="removing === member.userId" @click="confirming = ''">取消</button></div>
        </template>
      </article>
    </section>
  </main>
</template>
