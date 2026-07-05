<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { formatChatDisplayTime, useChatStore } from '@/stores/chat';
import { useMessageSearchStore } from '@/stores/message-search';
import type { MessageSearchResult, MessageType } from '@/types/chat';

const route = useRoute();
const router = useRouter();
const chatStore = useChatStore();
const searchStore = useMessageSearchStore();

const roomOptions = computed(() => chatStore.chats.filter((chat) => chat.type !== 'favorite'));

const typeOptions: Array<{ label: string; value: MessageType | '' }> = [
  { label: '全部类型', value: '' },
  { label: '文本', value: 'text' },
  { label: '图片', value: 'image' },
  { label: '语音', value: 'audio' },
  { label: '视频', value: 'video' },
  { label: '文件', value: 'file' },
  { label: '系统消息', value: 'system' },
  { label: '多媒体', value: 'mixed' },
];

const goBack = async () => {
  await router.push({ name: 'home' });
};

const submitSearch = async () => {
  await searchStore.search();
};

const filterAndSearch = async () => {
  if (!searchStore.hasQuery) return;
  await searchStore.search();
};

const openResult = async (result: MessageSearchResult) => {
  await router.push({
    name: 'chat-detail',
    params: { roomId: result.roomId },
    query: { messageId: result.id },
  });
};

const typeLabel = (type: MessageType) => typeOptions.find((item) => item.value === type)?.label ?? '消息';

onMounted(async () => {
  await chatStore.initialize();
  const queryRoomId = String(route.query.roomId ?? '');
  const queryKeyword = String(route.query.q ?? '');
  if (queryRoomId) searchStore.setRoomId(queryRoomId);
  if (queryKeyword) {
    searchStore.setKeyword(queryKeyword);
    await searchStore.search();
  }
});
</script>

<template>
  <main class="message-search app-phone-frame">
    <header class="message-search__header">
      <button class="message-search__back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>本地消息</p>
        <h1>搜索聊天记录</h1>
      </div>
    </header>

    <form class="message-search__form" @submit.prevent="submitSearch">
      <label class="message-search__input">
        <span class="sr-only">搜索聊天记录</span>
        <input
          v-model="searchStore.keyword"
          class="rc-focus-ring"
          autocomplete="off"
          placeholder="输入关键词、联系人或群名"
        />
      </label>
      <button class="message-search__submit rc-focus-ring" type="submit" :disabled="searchStore.loading || !searchStore.hasQuery">
        搜索
      </button>
    </form>

    <section class="message-search__filters" aria-label="消息搜索筛选">
      <label>
        <span>会话</span>
        <select v-model="searchStore.roomId" class="rc-focus-ring" @change="filterAndSearch">
          <option value="">全部会话</option>
          <option v-for="room in roomOptions" :key="room.roomId" :value="room.roomId">
            {{ room.name }}
          </option>
        </select>
      </label>
      <label>
        <span>类型</span>
        <select v-model="searchStore.messageType" class="rc-focus-ring" @change="filterAndSearch">
          <option v-for="option in typeOptions" :key="option.value || 'all'" :value="option.value">
            {{ option.label }}
          </option>
        </select>
      </label>
    </section>

    <p class="message-search__summary" :class="{ 'message-search__summary--error': searchStore.error }">
      {{ searchStore.summary }}
    </p>

    <section class="message-search__results" aria-label="消息搜索结果">
      <p v-if="searchStore.loading && searchStore.results.length === 0" class="message-search__empty">
        正在搜索本地消息...
      </p>
      <p v-else-if="searchStore.hasQuery && !searchStore.loading && searchStore.results.length === 0" class="message-search__empty">
        没有找到匹配的消息。可以换一个关键词，或进入聊天详情后等待本地索引重建。
      </p>
      <p v-else-if="!searchStore.hasQuery" class="message-search__empty">
        支持搜索消息正文、发送人和会话名称；结果来自浏览器本地缓存。
      </p>

      <article
        v-for="result in searchStore.results"
        :key="`${result.roomId}-${result.id}`"
        class="message-search__result"
      >
        <button class="message-search__result-button rc-focus-ring" type="button" @click="openResult(result)">
          <div class="message-search__result-top">
            <h2>{{ result.roomName || '聊天' }}</h2>
            <time>{{ formatChatDisplayTime(result.timestamp) }}</time>
          </div>
          <p class="message-search__meta">
            {{ result.senderName || 'RedCode 用户' }} · {{ typeLabel(result.messageType) }}
          </p>
          <p class="message-search__content">
            {{ result.matchedText || result.content || '[非文本消息]' }}
          </p>
        </button>
      </article>

      <button
        v-if="searchStore.hasMore"
        class="message-search__more rc-focus-ring"
        type="button"
        :disabled="searchStore.loading"
        @click="searchStore.loadMore"
      >
        {{ searchStore.loading ? '加载中...' : '加载更多' }}
      </button>
    </section>
  </main>
</template>

<style scoped>
.message-search {
  min-height: 100dvh;
  overflow-x: hidden;
  background: var(--rc-background);
  padding: calc(var(--rc-safe-top) + 14px) 16px 28px;
}

.message-search__header {
  display: grid;
  grid-template-columns: 44px 1fr;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
}

.message-search__back {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-surface);
  color: var(--rc-text-primary);
  font-size: 34px;
  line-height: 1;
}

.message-search__header p,
.message-search__meta,
.message-search__summary,
.message-search__empty {
  margin: 0;
  color: var(--rc-text-secondary);
  font-size: 13px;
}

.message-search__header h1 {
  margin: 2px 0 0;
  color: var(--rc-text-black);
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.03em;
}

.message-search__form {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
  margin-bottom: 12px;
}

.message-search__input input,
.message-search__filters select {
  width: 100%;
  height: 44px;
  border: 0;
  border-radius: 44px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 16px;
}

.message-search__submit,
.message-search__more {
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
  padding: 0 18px;
}

.message-search__submit:disabled,
.message-search__more:disabled {
  cursor: not-allowed;
  opacity: 0.58;
}

.message-search__filters {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 12px;
}

.message-search__filters label {
  display: grid;
  gap: 6px;
  color: var(--rc-text-secondary);
  font-size: 12px;
  font-weight: 700;
}

.message-search__summary {
  border-radius: 16px;
  background: var(--rc-surface);
  padding: 12px 14px;
}

.message-search__summary--error {
  background: #feeceb;
  color: var(--rc-danger);
}

.message-search__results {
  display: grid;
  gap: 10px;
  margin-top: 12px;
}

.message-search__empty {
  border-radius: 18px;
  background: var(--rc-surface);
  line-height: 1.5;
  padding: 16px;
}

.message-search__result {
  border-radius: 20px;
  background: var(--rc-surface);
  overflow: hidden;
}

.message-search__result-button {
  display: grid;
  gap: 7px;
  width: 100%;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  text-align: left;
  padding: 14px;
}

.message-search__result-button:hover {
  background: var(--rc-surface-muted);
}

.message-search__result-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.message-search__result-top h2 {
  margin: 0;
  overflow: hidden;
  color: var(--rc-text-primary);
  font-size: 16px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.message-search__result-top time {
  flex: 0 0 auto;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.message-search__content {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: var(--rc-text-primary);
  font-size: 14px;
  line-height: 1.45;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.message-search__more {
  min-height: 44px;
}
</style>
