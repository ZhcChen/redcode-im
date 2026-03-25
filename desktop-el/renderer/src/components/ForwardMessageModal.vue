<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface ForwardChatTarget {
  id: string;
  title: string;
  subtitle: string | null;
  avatarUrl: string | null;
  roomType: "private" | "group" | "public" | "favorite";
  lastMessagePreview: string;
}

const props = defineProps<{
  visible: boolean;
  chats: ForwardChatTarget[];
  sourceSummary: string | null;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "submit", payload: { targetRoomId: string; targetTitle: string }): void;
}>();

const searchQuery = ref("");
const selectedChatId = ref<string | null>(null);
const validationMessage = ref<string | null>(null);

const filteredChats = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();
  if (!keyword) {
    return props.chats;
  }

  return props.chats.filter((chat) => {
    const title = chat.title.toLowerCase();
    const subtitle = chat.subtitle?.toLowerCase() ?? "";
    const preview = chat.lastMessagePreview.toLowerCase();
    return (
      title.includes(keyword) ||
      subtitle.includes(keyword) ||
      preview.includes(keyword)
    );
  });
});

const selectedChat = computed(
  () => props.chats.find((chat) => chat.id === selectedChatId.value) ?? null,
);

const buildAvatarFallback = (title: string) =>
  title.trim().slice(0, 1).toUpperCase() || "#";

const formatRoomType = (roomType: ForwardChatTarget["roomType"]) => {
  switch (roomType) {
    case "group":
      return "群聊";
    case "favorite":
      return "收藏夹";
    case "public":
      return "公开频道";
    case "private":
    default:
      return "单聊";
  }
};

const resetForm = () => {
  searchQuery.value = "";
  selectedChatId.value = null;
  validationMessage.value = null;
};

const close = () => {
  if (props.isSubmitting) {
    return;
  }
  emit("update:visible", false);
};

const selectChat = (chatId: string) => {
  selectedChatId.value = chatId;
  validationMessage.value = null;
};

const handleSubmit = () => {
  if (!selectedChat.value) {
    validationMessage.value = "请选择目标会话";
    return;
  }

  validationMessage.value = null;
  emit("submit", {
    targetRoomId: selectedChat.value.id,
    targetTitle: selectedChat.value.title,
  });
};

watch(
  () => props.visible,
  (visible, previousVisible) => {
    if ((visible && !previousVisible) || (!visible && previousVisible)) {
      resetForm();
    }
  },
);
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="forward-message-modal">
      <div class="forward-message-modal__backdrop" @click="close" />
      <section class="forward-message-modal__panel">
        <header class="forward-message-modal__header">
          <div>
            <p class="forward-message-modal__eyebrow">消息</p>
            <h2>转发消息</h2>
            <small>
              {{
                props.sourceSummary
                  ? `原消息：${props.sourceSummary}`
                  : "选择一个目标会话，转发当前消息。"
              }}
            </small>
          </div>
          <button
            type="button"
            class="forward-message-modal__button forward-message-modal__button--ghost"
            @click="close"
          >
            关闭
          </button>
        </header>

        <form class="forward-message-modal__content" @submit.prevent="handleSubmit">
          <div class="forward-message-modal__toolbar">
            <input
              v-model="searchQuery"
              class="forward-message-modal__search"
              type="search"
              placeholder="搜索目标会话"
              :disabled="props.isSubmitting"
            />
            <small>{{
              selectedChat ? `已选择：${selectedChat.title}` : "尚未选择会话"
            }}</small>
          </div>

          <div v-if="!filteredChats.length" class="forward-message-modal__empty">
            <strong>{{
              props.chats.length ? "暂无匹配会话" : "暂无可转发目标"
            }}</strong>
            <p>
              {{
                props.chats.length
                  ? "换个关键词试试"
                  : "请先在当前账号下创建或进入其他会话"
              }}
            </p>
          </div>

          <div v-else class="forward-message-modal__list">
            <button
              v-for="chat in filteredChats"
              :key="chat.id"
              type="button"
              class="forward-message-modal__chat"
              :class="{
                'forward-message-modal__chat--active': selectedChatId === chat.id,
              }"
              :disabled="props.isSubmitting"
              @click="selectChat(chat.id)"
            >
              <span class="forward-message-modal__avatar">
                <img
                  v-if="chat.avatarUrl"
                  :src="chat.avatarUrl"
                  :alt="chat.title"
                />
                <span v-else>{{ buildAvatarFallback(chat.title) }}</span>
              </span>
              <span class="forward-message-modal__copy">
                <span class="forward-message-modal__title">
                  <strong>{{ chat.title }}</strong>
                  <small>{{ formatRoomType(chat.roomType) }}</small>
                </span>
                <small>{{
                  chat.subtitle || chat.lastMessagePreview || "暂无会话摘要"
                }}</small>
              </span>
              <span class="forward-message-modal__check">{{
                selectedChatId === chat.id ? "已选" : "选择"
              }}</span>
            </button>
          </div>

          <p v-if="validationMessage" class="forward-message-modal__error">
            {{ validationMessage }}
          </p>

          <footer class="forward-message-modal__footer">
            <button
              type="button"
              class="forward-message-modal__button forward-message-modal__button--ghost"
              :disabled="props.isSubmitting"
              @click="close"
            >
              取消
            </button>
            <button
              type="submit"
              class="forward-message-modal__button"
              :disabled="props.isSubmitting || !selectedChatId"
            >
              {{ props.isSubmitting ? "转发中..." : "确认转发" }}
            </button>
          </footer>
        </form>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.forward-message-modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 24px;
}

.forward-message-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.forward-message-modal__panel {
  position: relative;
  z-index: 1;
  width: min(760px, 100%);
  max-height: min(82vh, 820px);
  overflow: auto;
  display: grid;
  gap: 18px;
  padding: 28px;
  border-radius: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.98),
    rgba(241, 245, 249, 0.96)
  );
  box-shadow: 0 30px 80px rgba(15, 23, 42, 0.24);
}

.forward-message-modal__header,
.forward-message-modal__toolbar,
.forward-message-modal__chat,
.forward-message-modal__title,
.forward-message-modal__footer {
  display: flex;
  align-items: center;
  gap: 12px;
}

.forward-message-modal__header,
.forward-message-modal__toolbar,
.forward-message-modal__footer {
  justify-content: space-between;
}

.forward-message-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.forward-message-modal__header h2,
.forward-message-modal__empty strong,
.forward-message-modal__title strong {
  margin: 0;
  color: var(--text-primary);
}

.forward-message-modal__header small,
.forward-message-modal__title small,
.forward-message-modal__copy > small,
.forward-message-modal__empty p,
.forward-message-modal__toolbar small {
  color: var(--text-secondary);
}

.forward-message-modal__content,
.forward-message-modal__list,
.forward-message-modal__copy {
  display: grid;
  gap: 12px;
}

.forward-message-modal__search {
  width: min(320px, 100%);
  height: 44px;
  padding: 0 14px;
  border-radius: 14px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.9);
  color: var(--text-primary);
}

.forward-message-modal__chat {
  justify-content: space-between;
  padding: 14px 16px;
  border-radius: 18px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.78);
  text-align: left;
  cursor: pointer;
}

.forward-message-modal__chat--active {
  border-color: rgba(0, 155, 143, 0.28);
  background: rgba(0, 194, 179, 0.12);
}

.forward-message-modal__avatar {
  width: 42px;
  height: 42px;
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 14px;
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-primary);
  font-weight: 700;
  overflow: hidden;
}

.forward-message-modal__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.forward-message-modal__copy {
  flex: 1;
  min-width: 0;
}

.forward-message-modal__title {
  justify-content: flex-start;
}

.forward-message-modal__title strong,
.forward-message-modal__copy > small {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.forward-message-modal__check {
  min-width: 44px;
  text-align: right;
  color: var(--primary-color-strong);
  font-size: 12px;
  font-weight: 600;
}

.forward-message-modal__empty {
  display: grid;
  gap: 6px;
  padding: 24px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.72);
  border: 1px dashed rgba(15, 23, 42, 0.12);
  text-align: center;
}

.forward-message-modal__error {
  margin: 0;
  color: var(--error-color);
  font-size: 13px;
}

.forward-message-modal__button {
  height: 40px;
  padding: 0 18px;
  border: none;
  border-radius: 999px;
  background: linear-gradient(135deg, #0f766e, #14b8a6);
  color: #ffffff;
  font-weight: 600;
  cursor: pointer;
}

.forward-message-modal__button--ghost {
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-primary);
}

.forward-message-modal__button:disabled,
.forward-message-modal__chat:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

@media (max-width: 720px) {
  .forward-message-modal {
    padding: 12px;
  }

  .forward-message-modal__panel {
    padding: 20px;
  }

  .forward-message-modal__header,
  .forward-message-modal__toolbar,
  .forward-message-modal__chat,
  .forward-message-modal__footer {
    flex-direction: column;
    align-items: stretch;
  }

  .forward-message-modal__search {
    width: 100%;
  }

  .forward-message-modal__check {
    text-align: left;
  }
}
</style>
