<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useAuthStore } from '@/stores/auth';
import { useMessageActionsStore } from '@/stores/message-actions';
import type { MessageReader, MessageReceiptMember } from '@/types/chat';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const store = useMessageActionsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const messageId = computed(() => String(route.params.messageId ?? ''));
const senderId = computed(() => authStore.currentUser?.id ?? '');
const showUnread = ref(false);

const goBack = () => router.push({ name: 'chat-detail', params: { roomId: roomId.value } });
const formatReadTime = (timestamp: number) => new Intl.DateTimeFormat('zh-CN', {
  month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
}).format(new Date(timestamp));
const readStateLabel = (reader: MessageReader | MessageReceiptMember) => (
  'readAt' in reader ? formatReadTime(reader.readAt) : '未读'
);

onMounted(() => {
  void store.loadReaders(roomId.value, messageId.value, senderId.value);
});
</script>

<template>
  <main class="message-action-page app-phone-frame">
    <header class="message-action-header">
      <button class="message-action-back rc-focus-ring" type="button" aria-label="返回" @click="goBack">‹</button>
      <div><p>消息状态</p><h1>已读成员</h1></div>
      <button class="message-action-refresh rc-focus-ring" type="button" :disabled="store.loadingReaders" @click="store.loadReaders(roomId, messageId, senderId)">刷新</button>
    </header>
    <section class="message-action-content">
      <p v-if="store.error" class="message-action-notice message-action-notice--error">{{ store.error }}</p>
      <p v-if="store.loadingReaders" class="message-action-empty">正在加载已读成员...</p>
      <template v-else>
        <div class="receipt-tabs" role="tablist" aria-label="阅读状态">
          <button class="rc-focus-ring" :class="{ active: !showUnread }" type="button" @click="showUnread = false">已读 {{ store.eligibleReaders.length }}</button>
          <button class="rc-focus-ring" :class="{ active: showUnread }" type="button" @click="showUnread = true">未读 {{ store.unreadMembers.length }}</button>
        </div>
        <p v-if="showUnread && store.unreadMembers.length === 0" class="message-action-empty">没有未读成员</p>
        <p v-else-if="!showUnread && store.eligibleReaders.length === 0" class="message-action-empty">没有已读成员</p>
        <article v-for="reader in showUnread ? store.unreadMembers : store.eligibleReaders" :key="reader.userId" class="reader-row">
          <CachedAvatar kind="user" :entity-id="reader.userId" :label="reader.nickname || reader.username" :size="42" />
          <div><h2>{{ reader.nickname || reader.username }}</h2><p>{{ reader.username }}</p></div>
          <time>{{ readStateLabel(reader) }}</time>
        </article>
      </template>
    </section>
  </main>
</template>

<style scoped src="./message-action-page.css"></style>
