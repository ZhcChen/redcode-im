<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedAttachment from '@/components/CachedAttachment.vue';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useAuthStore } from '@/stores/auth';
import { useChatStore } from '@/stores/chat';
import { useChatDetailStore } from '@/stores/chat-detail';
import type { ChatMessage } from '@/types/chat';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const chatStore = useChatStore();
const detailStore = useChatDetailStore();
const draft = ref('');
const listEl = ref<HTMLElement | null>(null);
const imageInput = ref<HTMLInputElement | null>(null);
const fileInput = ref<HTMLInputElement | null>(null);

const roomId = computed(() => String(route.params.roomId ?? ''));
const currentUserId = computed(() => authStore.currentUser?.id ?? '');

const scrollToBottom = async () => {
  await nextTick();
  if (!listEl.value) return;
  listEl.value.scrollTop = listEl.value.scrollHeight;
};

const send = async () => {
  const content = draft.value.trim();
  if (!content) return;
  draft.value = '';
  await detailStore.sendText(content);
  await scrollToBottom();
};

const chooseAttachment = (type: 'image' | 'file') => {
  (type === 'image' ? imageInput.value : fileInput.value)?.click();
};

const sendAttachment = async (event: Event, type: 'image' | 'file') => {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  await detailStore.sendAttachment(file, type);
  await scrollToBottom();
};

const goBack = async () => {
  await router.push({ name: 'home' });
};

const openGroupSettings = async () => {
  const targetRoomId = detailStore.roomId || roomId.value;
  if (!targetRoomId) return;
  await router.push({ name: 'group-settings', params: { roomId: targetRoomId } });
};

const openMessageSearch = async () => {
  const targetRoomId = detailStore.roomId || roomId.value;
  await router.push({
    name: 'message-search',
    query: targetRoomId ? { roomId: targetRoomId } : {},
  });
};

const isSelf = (message: ChatMessage) => message.senderId === currentUserId.value;

const messageStatusLabel = (message: ChatMessage) => {
  if (message.status === 'sending') return '发送中';
  if (message.status === 'failed') return '发送失败';
  return '';
};

const quotePreview = (message: ChatMessage) => {
  const quoted = message.quotedMessage;
  if (!quoted) return '';
  const content = quoted.isDeleted ? '引用的消息已删除' : quoted.content || '[非文本消息]';
  return `${quoted.senderName || 'RedCode 用户'}：${content}`;
};

const deleteMessage = async (message: ChatMessage) => {
  if (!isSelf(message) || message.isDeleted) return;
  await detailStore.deleteMessage(message.id);
};

const togglePin = async (message: ChatMessage) => {
  if (message.isDeleted) return;
  await detailStore.setMessagePinned(message.id, !message.isPinned);
};

const openReadDetails = async (message: ChatMessage) => {
  await router.push({
    name: 'message-reads',
    params: { roomId: roomId.value, messageId: message.id },
  });
};

const openForward = async (message: ChatMessage) => {
  await router.push({
    name: 'message-forward',
    params: { roomId: roomId.value, messageId: message.id },
  });
};

onMounted(async () => {
  await chatStore.initialize();
  const chat = resolveRouteChat();
  await detailStore.enterRoom(chat?.roomId ?? roomId.value, chat);
  await scrollToBottom();
});

onBeforeUnmount(() => {
  detailStore.leaveRoom();
});

watch(() => detailStore.messages.length, () => {
  void scrollToBottom();
});

const resolveRouteChat = () => {
  const targetRoomId = roomId.value;
  return chatStore.chats.find((item) => item.roomId === targetRoomId)
    ?? (targetRoomId === 'favorite' ? chatStore.chats.find((item) => item.type === 'favorite') : null)
    ?? null;
};
</script>

<template>
  <main class="chat-detail app-phone-frame">
    <header class="chat-detail__header">
      <button class="chat-detail__back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div class="chat-detail__title">
        <h1>{{ detailStore.title }}</h1>
        <p>{{ detailStore.loading ? '同步中' : `${detailStore.messages.length} 条消息` }}</p>
      </div>
      <div class="chat-detail__actions">
        <button
          class="chat-detail__icon-action rc-focus-ring"
          type="button"
          aria-label="搜索消息"
          @click="openMessageSearch"
        >
          ⌕
        </button>
        <button
          v-if="detailStore.chat?.type === 'group'"
          class="chat-detail__icon-action rc-focus-ring"
          type="button"
          aria-label="群设置"
          @click="openGroupSettings"
        >
          ⋯
        </button>
      </div>
    </header>

    <section ref="listEl" class="message-list" aria-label="聊天消息">
      <p v-if="detailStore.error" class="message-notice message-notice--error">
        {{ detailStore.error }}
      </p>
      <p v-if="detailStore.loading && detailStore.messages.length === 0" class="message-notice">
        正在加载消息...
      </p>
      <p v-else-if="detailStore.messages.length === 0" class="message-notice">
        暂无消息，发送第一条消息开始聊天。
      </p>

      <article
        v-for="message in detailStore.messages"
        :key="message.id"
        class="message-row"
        :class="{ 'message-row--self': isSelf(message) }"
      >
        <CachedAvatar
          v-if="!isSelf(message)"
          class="message-row__avatar"
          kind="user"
          :entity-id="message.senderId"
          :object-key="message.raw?.sender_avatar_object_key ? String(message.raw.sender_avatar_object_key) : null"
          :label="message.senderName || 'RedCode 用户'"
          :size="34"
        />
        <div class="message-row__body">
          <p v-if="!isSelf(message)" class="message-row__sender">{{ message.senderName || 'RedCode 用户' }}</p>
          <div class="message-bubble">
            <div v-if="message.isPinned" class="message-bubble__pin">已置顶</div>
            <button
              v-if="message.quotedMessage"
              class="message-bubble__quote rc-focus-ring"
              type="button"
              @click="detailStore.quoteMessage(message.quotedMessage.id)"
            >
              {{ quotePreview(message) }}
            </button>
            {{ message.isDeleted ? '[消息已删除]' : message.content }}
            <CachedAttachment
              v-for="attachment in message.attachments ?? []"
              :key="attachment.key"
              :room-id="message.roomId"
              :attachment="attachment"
            />
          </div>
          <div v-if="!message.isDeleted" class="message-row__actions">
            <button class="rc-focus-ring" type="button" @click="detailStore.quoteMessage(message.id)">引用</button>
            <button class="rc-focus-ring" type="button" @click="togglePin(message)">
              {{ message.isPinned ? '取消置顶' : '置顶' }}
            </button>
            <button class="rc-focus-ring" type="button" @click="openForward(message)">转发</button>
            <button v-if="isSelf(message) && detailStore.chat?.type === 'group'" class="rc-focus-ring" type="button" @click="openReadDetails(message)">已读详情</button>
            <button
              v-if="isSelf(message)"
              class="message-row__danger rc-focus-ring"
              type="button"
              @click="deleteMessage(message)"
            >
              删除
            </button>
          </div>
          <div v-if="messageStatusLabel(message)" class="message-row__status">
            <span>{{ messageStatusLabel(message) }}</span>
            <button
              v-if="message.status === 'failed'"
              class="rc-focus-ring"
              type="button"
              @click="detailStore.resendMessage(message.id)"
            >
              重发
            </button>
          </div>
        </div>
      </article>
    </section>

    <footer class="message-composer-shell">
      <div v-if="detailStore.quotedMessage" class="message-composer__quote">
        <span>引用：{{ detailStore.quotedMessage.senderName || 'RedCode 用户' }}：{{ detailStore.quotedMessage.content || '[非文本消息]' }}</span>
        <button class="rc-focus-ring" type="button" @click="detailStore.clearQuote">取消</button>
      </div>
      <div v-if="detailStore.uploadingAttachment || detailStore.failedAttachment" class="message-composer__upload">
        <span>{{ detailStore.uploadingAttachment ? '正在发送附件...' : `发送失败：${detailStore.failedAttachment?.file.name}` }}</span>
        <button v-if="detailStore.uploadingAttachment" class="rc-focus-ring" type="button" @click="detailStore.cancelAttachmentUpload">取消</button>
        <button v-else class="rc-focus-ring" type="button" @click="detailStore.retryAttachment">重试</button>
      </div>
      <form class="message-composer" @submit.prevent="send">
        <input ref="imageInput" class="sr-only" type="file" accept="image/*" aria-label="选择图片" @change="sendAttachment($event, 'image')" />
        <input ref="fileInput" class="sr-only" type="file" aria-label="选择文件" @change="sendAttachment($event, 'file')" />
        <button class="message-composer__tool rc-focus-ring" type="button" aria-label="发送图片" :disabled="detailStore.uploadingAttachment" @click="chooseAttachment('image')">图片</button>
        <button class="message-composer__tool rc-focus-ring" type="button" aria-label="发送文件" :disabled="detailStore.uploadingAttachment" @click="chooseAttachment('file')">文件</button>
        <label class="sr-only" for="message-input">输入消息</label>
        <input
          id="message-input"
          v-model="draft"
          class="rc-focus-ring"
          autocomplete="off"
          placeholder="输入消息"
          :disabled="detailStore.sending && !draft"
        />
        <button class="message-composer__send rc-focus-ring" type="submit" :disabled="!draft.trim()">
          发送
        </button>
      </form>
    </footer>
  </main>
</template>

<style scoped>
.chat-detail {
  display: grid;
  grid-template-rows: auto 1fr auto;
  height: 100dvh;
  overflow: hidden;
  background: var(--rc-background);
}

.chat-detail__header {
  display: grid;
  grid-template-columns: 44px 1fr auto;
  align-items: center;
  padding: calc(var(--rc-safe-top) + 10px) 12px 12px;
  background: var(--rc-surface);
  box-shadow: 0 1px 0 var(--rc-divider);
}

.chat-detail__back {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 34px;
  line-height: 1;
}

.chat-detail__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
}

.chat-detail__icon-action {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 24px;
  line-height: 1;
}

.chat-detail__title {
  min-width: 0;
  text-align: center;
}

.chat-detail__title h1 {
  margin: 0;
  overflow: hidden;
  color: var(--rc-text-primary);
  font-size: 17px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-detail__title p {
  margin: 4px 0 0;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.message-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  overflow-y: auto;
  padding: 16px 14px 18px;
}

.message-notice {
  margin: 0 auto;
  max-width: 86%;
  border-radius: 999px;
  background: rgb(255 255 255 / 72%);
  color: var(--rc-text-secondary);
  font-size: 13px;
  padding: 8px 12px;
  text-align: center;
}

.message-notice--error {
  background: #feeceb;
  color: var(--rc-danger);
}

.message-row {
  display: flex;
  align-items: flex-start;
  gap: 9px;
}

.message-row--self {
  justify-content: flex-end;
}

.message-row__avatar {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  border-radius: 999px;
  background: linear-gradient(180deg, #00db4d 0%, #00c27b 100%);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
}

.message-row__body {
  display: grid;
  justify-items: start;
  max-width: 76%;
  gap: 4px;
}

.message-row--self .message-row__body {
  justify-items: end;
}

.message-row__sender {
  margin: 0 0 1px;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.message-bubble {
  border-radius: 18px 18px 18px 4px;
  background: var(--rc-surface);
  color: var(--rc-text-primary);
  font-size: 15px;
  line-height: 1.45;
  overflow-wrap: anywhere;
  padding: 10px 13px;
  box-shadow: 0 1px 0 rgb(0 0 0 / 4%);
}

.message-row--self .message-bubble {
  border-radius: 18px 18px 4px;
  background: var(--rc-primary);
  color: #fff;
}

.message-bubble__pin {
  width: fit-content;
  margin: 0 0 6px;
  border-radius: 999px;
  background: rgb(255 255 255 / 28%);
  color: inherit;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 7px;
}

.message-bubble__quote {
  display: block;
  width: 100%;
  max-width: 220px;
  margin: 0 0 7px;
  border-radius: 10px;
  cursor: pointer;
  background: rgb(0 0 0 / 5%);
  color: var(--rc-text-secondary);
  font-size: 12px;
  line-height: 1.35;
  overflow: hidden;
  padding: 7px 9px;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.message-row--self .message-bubble__quote {
  background: rgb(255 255 255 / 18%);
  color: rgb(255 255 255 / 84%);
}

.message-row__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0.78;
}

.message-row__actions button {
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-tertiary);
  font-size: 12px;
  font-weight: 700;
}

.message-row__actions .message-row__danger {
  color: var(--rc-danger);
}

.message-row__status {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.message-row__status button {
  cursor: pointer;
  background: transparent;
  color: var(--rc-danger);
  font-size: 12px;
  font-weight: 700;
}

.message-composer-shell {
  display: grid;
  gap: 8px;
  padding: 10px 12px calc(10px + var(--rc-safe-bottom));
  background: var(--rc-surface);
  box-shadow: var(--rc-shadow-nav);
}

.message-composer__quote {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  gap: 10px;
  border-radius: 12px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-secondary);
  font-size: 12px;
  line-height: 1.35;
  padding: 8px 10px;
}

.message-composer__quote span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.message-composer__quote button {
  cursor: pointer;
  background: transparent;
  color: var(--rc-primary);
  font-size: 12px;
  font-weight: 700;
}

.message-composer {
  display: grid;
  grid-template-columns: auto auto 1fr auto;
  gap: 10px;
}

.message-composer__upload {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: var(--rc-text-secondary);
  font-size: 12px;
}

.message-composer__upload button,
.message-composer__tool {
  cursor: pointer;
  background: transparent;
  color: var(--rc-primary);
  font-weight: 700;
}

.message-composer__tool {
  min-width: 38px;
  padding: 0 2px;
  font-size: 12px;
}

.message-composer__tool:disabled {
  cursor: not-allowed;
  color: var(--rc-text-tertiary);
}

.message-composer input {
  min-width: 0;
  height: 42px;
  border: 0;
  border-radius: 999px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 16px;
}

.message-composer__send {
  min-width: 58px;
  height: 42px;
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.message-composer__send:disabled {
  cursor: not-allowed;
  background: var(--rc-divider);
  color: var(--rc-text-tertiary);
}
</style>
