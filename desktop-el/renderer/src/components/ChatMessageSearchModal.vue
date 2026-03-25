<script setup lang="ts">
import { computed, ref, watch } from "vue";
import type { ChatMessage } from "@/api/chat";
import {
  searchLocalChatMessages,
  type LocalChatMessageSearchResult,
} from "@/utils/chat-message-search";

const props = defineProps<{
  visible: boolean;
  roomTitle: string | null;
  messages: ChatMessage[];
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "select", payload: LocalChatMessageSearchResult): void;
}>();

const searchQuery = ref("");

const results = computed(() =>
  searchLocalChatMessages(props.messages, searchQuery.value, {
    limit: 80,
  }),
);

const close = () => {
  emit("update:visible", false);
};

const handleSelect = (result: LocalChatMessageSearchResult) => {
  emit("select", result);
};

const formatMessageType = (messageType: ChatMessage["messageType"]) => {
  switch (messageType) {
    case "audio":
      return "语音";
    case "file":
      return "文件";
    case "image":
      return "图片";
    case "mixed":
      return "混合";
    case "video":
      return "视频";
    case "text":
    default:
      return "文本";
  }
};

const formatResultTime = (value: Date | null) => {
  if (!value) {
    return "时间未知";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
};

watch(
  () => props.visible,
  (visible, previousVisible) => {
    if (visible && !previousVisible) {
      searchQuery.value = "";
    }
  },
);
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="chat-message-search-modal">
      <div class="chat-message-search-modal__backdrop" @click="close" />
      <section class="chat-message-search-modal__panel">
        <header class="chat-message-search-modal__header">
          <div>
            <p class="chat-message-search-modal__eyebrow">本地搜索</p>
            <h2>搜索消息</h2>
            <small>
              {{
                props.roomTitle
                  ? `仅搜索当前会话“${props.roomTitle}”已加载的本地消息。`
                  : "仅搜索当前会话已加载的本地消息。"
              }}
            </small>
          </div>
          <button
            type="button"
            class="chat-message-search-modal__button chat-message-search-modal__button--ghost"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="chat-message-search-modal__toolbar">
          <input
            v-model="searchQuery"
            class="chat-message-search-modal__input"
            type="search"
            placeholder="搜索消息内容、附件名或引用内容"
            @keydown.esc="close"
          />
          <small>
            {{
              searchQuery.trim()
                ? `命中 ${results.length} 条`
                : `当前可搜索 ${props.messages.length} 条已加载消息`
            }}
          </small>
        </div>

        <div v-if="!searchQuery.trim()" class="chat-message-search-modal__empty">
          <strong>输入关键词开始搜索</strong>
          <p>当前搜索不会请求 Go core，也不会额外打开本地端口。</p>
        </div>

        <div
          v-else-if="!results.length"
          class="chat-message-search-modal__empty"
        >
          <strong>暂无命中结果</strong>
          <p>换个关键词试试，或先把更多历史消息同步到当前会话。</p>
        </div>

        <div v-else class="chat-message-search-modal__results">
          <button
            v-for="result in results"
            :key="result.messageId"
            type="button"
            class="chat-message-search-modal__result"
            @click="handleSelect(result)"
          >
            <span class="chat-message-search-modal__result-meta">
              <strong>{{ result.senderName }}</strong>
              <small>{{ formatResultTime(result.createdAt) }}</small>
            </span>
            <span
              class="chat-message-search-modal__result-body"
              v-html="result.highlightedHtml"
            />
            <span class="chat-message-search-modal__result-footer">
              <small>{{ result.summaryText }}</small>
              <span class="chat-message-search-modal__badge">
                {{ formatMessageType(result.messageType) }}
              </span>
            </span>
          </button>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.chat-message-search-modal {
  position: fixed;
  inset: 0;
  z-index: 54;
  display: grid;
  place-items: center;
  padding: 24px;
}

.chat-message-search-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.42);
  backdrop-filter: blur(10px);
}

.chat-message-search-modal__panel {
  position: relative;
  z-index: 1;
  width: min(760px, 100%);
  max-height: min(84vh, 820px);
  overflow: auto;
  display: grid;
  gap: 18px;
  padding: 28px;
  border-radius: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background:
    radial-gradient(circle at top left, rgba(251, 191, 36, 0.12), transparent 32%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(241, 245, 249, 0.96));
  box-shadow: 0 30px 80px rgba(15, 23, 42, 0.24);
}

.chat-message-search-modal__header,
.chat-message-search-modal__toolbar,
.chat-message-search-modal__result-meta,
.chat-message-search-modal__result-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.chat-message-search-modal__header {
  align-items: flex-start;
}

.chat-message-search-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: rgba(15, 23, 42, 0.55);
}

.chat-message-search-modal__header h2 {
  margin: 0;
  color: var(--text-primary);
}

.chat-message-search-modal__header small,
.chat-message-search-modal__toolbar small,
.chat-message-search-modal__empty p,
.chat-message-search-modal__result-footer small {
  color: var(--text-secondary);
}

.chat-message-search-modal__input {
  flex: 1;
  height: 46px;
  border-radius: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.92);
  padding: 0 16px;
  color: var(--text-primary);
}

.chat-message-search-modal__results {
  display: grid;
  gap: 12px;
}

.chat-message-search-modal__result {
  display: grid;
  gap: 10px;
  width: 100%;
  padding: 16px 18px;
  border-radius: 20px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.88);
  text-align: left;
  cursor: pointer;
}

.chat-message-search-modal__result-body {
  color: var(--text-primary);
  line-height: 1.6;
}

.chat-message-search-modal__result-body :deep(mark) {
  padding: 0 3px;
  border-radius: 6px;
  background: rgba(251, 191, 36, 0.34);
  color: #92400e;
}

.chat-message-search-modal__badge {
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(0, 194, 179, 0.12);
  color: var(--primary-color-strong);
  font-size: 12px;
}

.chat-message-search-modal__empty {
  display: grid;
  gap: 8px;
  padding: 24px;
  border-radius: 22px;
  border: 1px dashed rgba(15, 23, 42, 0.12);
  background: rgba(241, 245, 249, 0.7);
}

.chat-message-search-modal__button {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  border: 1px solid transparent;
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
  cursor: pointer;
}

.chat-message-search-modal__button--ghost {
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
}

@media (max-width: 720px) {
  .chat-message-search-modal {
    padding: 16px;
  }

  .chat-message-search-modal__panel {
    padding: 22px;
  }

  .chat-message-search-modal__toolbar,
  .chat-message-search-modal__result-meta,
  .chat-message-search-modal__result-footer {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
