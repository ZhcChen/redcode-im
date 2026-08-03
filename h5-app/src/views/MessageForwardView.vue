<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useChatStore } from '@/stores/chat';
import { useMessageActionsStore } from '@/stores/message-actions';

const route = useRoute();
const router = useRouter();
const chatStore = useChatStore();
const actionStore = useMessageActionsStore();
const keyword = ref('');
const selectedRoomIds = ref<string[]>([]);
const sourceRoomId = computed(() => String(route.params.roomId ?? ''));
const messageId = computed(() => String(route.params.messageId ?? ''));
const chats = computed(() => {
  const query = keyword.value.trim().toLowerCase();
  return chatStore.chats.filter((chat) => chat.roomId !== sourceRoomId.value && chat.type !== 'favorite'
    && (!query || chat.name.toLowerCase().includes(query)));
});

const toggle = (roomId: string) => {
  selectedRoomIds.value = selectedRoomIds.value.includes(roomId)
    ? selectedRoomIds.value.filter((id) => id !== roomId)
    : [...selectedRoomIds.value, roomId];
};
const submit = async () => {
  const result = await actionStore.forwardMessage(messageId.value, selectedRoomIds.value);
  if (result.failed.length === 0 && result.succeeded.length > 0) {
    await router.push({ name: 'chat-detail', params: { roomId: sourceRoomId.value } });
  }
};
const goBack = () => router.push({ name: 'chat-detail', params: { roomId: sourceRoomId.value } });

onMounted(() => {
  actionStore.reset();
  void chatStore.initialize();
});
</script>

<template>
  <main class="message-action-page app-phone-frame">
    <header class="message-action-header">
      <button class="message-action-back rc-focus-ring" type="button" aria-label="返回" @click="goBack">‹</button>
      <div><p>消息操作</p><h1>转发消息</h1></div>
    </header>
    <section class="message-action-content message-action-content--forward">
      <label class="message-action-search"><span class="sr-only">搜索会话</span><input v-model="keyword" class="rc-focus-ring" placeholder="搜索会话" /></label>
      <p v-if="actionStore.error" class="message-action-notice message-action-notice--error">{{ actionStore.error }}</p>
      <p v-if="actionStore.notice" class="message-action-notice">{{ actionStore.notice }}</p>
      <p v-if="chats.length === 0" class="message-action-empty">暂无可转发的会话</p>
      <button v-for="chat in chats" :key="chat.roomId" class="forward-row rc-focus-ring" type="button" @click="toggle(chat.roomId)">
        <CachedAvatar :kind="chat.type === 'group' ? 'room' : 'user'" :entity-id="chat.roomId" :label="chat.name" :size="42" />
        <span><strong>{{ chat.name }}</strong><small>{{ chat.type === 'group' ? '群聊' : '单聊' }}</small></span>
        <input type="checkbox" :checked="selectedRoomIds.includes(chat.roomId)" tabindex="-1" aria-hidden="true" />
      </button>
    </section>
    <footer class="message-action-footer">
      <button class="message-action-submit rc-focus-ring" type="button" :disabled="selectedRoomIds.length === 0 || actionStore.forwarding" @click="submit">
        {{ actionStore.forwarding ? '正在转发...' : `转发给 ${selectedRoomIds.length} 个会话` }}
      </button>
    </footer>
  </main>
</template>

<style scoped src="./message-action-page.css"></style>
