<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { displayName } from '@/storage/contact-storage';
import { useContactsStore } from '@/stores/contacts';

const router = useRouter();
const store = useContactsStore();
const keyword = ref('');
const candidates = computed(() => {
  const query = keyword.value.trim().toLowerCase();
  return query ? store.friends.filter((friend) => [displayName(friend), friend.user.username].some((value) => value.toLowerCase().includes(query))) : store.friends;
});
const create = async () => {
  const roomId = await store.createGroup();
  if (roomId) await router.replace({ name: 'chat-detail', params: { roomId } });
};
onMounted(async () => { store.clearGroupDraft(); await store.initialize(); });
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-directory' })">‹</button>
      <div><h1>创建群聊</h1><p>已选择 {{ store.selectedFriendIds.length }} 位联系人</p></div>
      <button class="contact-page__primary rc-focus-ring" type="button" :disabled="store.submitting || !store.groupName.trim() || store.selectedFriendIds.length === 0" @click="create">创建</button>
    </header>
    <section class="contact-page__content">
      <label class="contact-page__field">群聊名称<input v-model="store.groupName" class="rc-focus-ring" maxlength="64" placeholder="输入群聊名称" /></label>
      <label class="contact-page__field">群简介（可选）<textarea v-model="store.groupDescription" class="rc-focus-ring" maxlength="200" placeholder="介绍群聊用途" /></label>
      <label class="contact-page__field">查找联系人<input v-model="keyword" class="rc-focus-ring" placeholder="搜索联系人" /></label>
      <p v-if="store.error" class="contact-page__notice contact-page__notice--error">{{ store.error }}</p>
      <p v-if="candidates.length === 0" class="contact-page__empty">没有可选择的联系人</p>
      <button v-for="friend in candidates" :key="friend.user.id" class="contact-page__row rc-focus-ring" type="button" @click="store.toggleGroupMember(friend.user.id)">
        <CachedAvatar kind="user" :entity-id="friend.user.id" :object-key="friend.user.avatarObjectKey" :label="displayName(friend)" :size="42" />
        <span><h2>{{ displayName(friend) }}</h2><p>{{ friend.user.username }}</p></span>
        <input type="checkbox" tabindex="-1" aria-hidden="true" :checked="store.selectedFriendIds.includes(friend.user.id)" />
      </button>
    </section>
  </main>
</template>
