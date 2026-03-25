<script setup lang="ts">
import { computed } from "vue";
import type { ChatMessageReader } from "@/api/chat";

const props = defineProps<{
  visible: boolean;
  readers: ChatMessageReader[];
  isLoading: boolean;
  messagePreview: string | null;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
}>();

const sortedReaders = computed(() =>
  [...props.readers].sort(
    (left, right) =>
      (right.readAt?.getTime() ?? 0) - (left.readAt?.getTime() ?? 0),
  ),
);

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const buildDisplayName = (reader: ChatMessageReader) =>
  reader.nickname?.trim() || reader.username || reader.userId;

const formatReadAt = (value: Date | null) => {
  if (!value) {
    return "已读时间待同步";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
};

const close = () => {
  emit("update:visible", false);
};
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="message-readers-modal">
      <div class="message-readers-modal__backdrop" @click="close" />
      <section class="message-readers-modal__panel">
        <header class="message-readers-modal__header">
          <div>
            <p class="message-readers-modal__eyebrow">消息</p>
            <h2>已读成员</h2>
            <small>{{
              props.messagePreview
                ? `消息：${props.messagePreview}`
                : "查看当前消息的已读成员列表。"
            }}</small>
          </div>
          <button
            type="button"
            class="message-readers-modal__button message-readers-modal__button--ghost"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="message-readers-modal__stats">
          <article class="message-readers-modal__stat">
            <strong>{{ props.readers.length }}</strong>
            <span>已读人数</span>
          </article>
        </div>

        <div v-if="props.isLoading" class="message-readers-modal__empty">
          <strong>加载中</strong>
          <p>正在同步消息已读成员...</p>
        </div>

        <div
          v-else-if="!sortedReaders.length"
          class="message-readers-modal__empty"
        >
          <strong>暂无已读成员</strong>
          <p>当前消息还没有返回已读成员数据。</p>
        </div>

        <div v-else class="message-readers-modal__list">
          <article
            v-for="reader in sortedReaders"
            :key="reader.userId"
            class="message-readers-modal__reader"
          >
            <span class="message-readers-modal__avatar">
              <img
                v-if="reader.avatarUrl"
                :src="reader.avatarUrl"
                :alt="buildDisplayName(reader)"
              />
              <span v-else>{{
                buildAvatarFallback(buildDisplayName(reader))
              }}</span>
            </span>
            <div class="message-readers-modal__copy">
              <strong>{{ buildDisplayName(reader) }}</strong>
              <small>{{ reader.username }}</small>
            </div>
            <div class="message-readers-modal__meta">
              <span>{{ formatReadAt(reader.readAt) }}</span>
            </div>
          </article>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.message-readers-modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 24px;
}

.message-readers-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.message-readers-modal__panel {
  position: relative;
  z-index: 1;
  width: min(720px, 100%);
  max-height: min(82vh, 760px);
  overflow: auto;
  display: grid;
  gap: 18px;
  border-radius: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.98),
    rgba(241, 245, 249, 0.96)
  );
  box-shadow: 0 30px 80px rgba(15, 23, 42, 0.24);
  padding: 28px;
}

.message-readers-modal__header,
.message-readers-modal__reader {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.message-readers-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.message-readers-modal__header h2 {
  margin: 0;
  color: var(--text-primary);
}

.message-readers-modal__header small,
.message-readers-modal__copy small,
.message-readers-modal__meta {
  color: var(--text-secondary);
}

.message-readers-modal__button {
  height: 40px;
  padding: 0 16px;
  border: none;
  border-radius: 999px;
  background: #0f172a;
  color: #ffffff;
  font-weight: 600;
  cursor: pointer;
}

.message-readers-modal__button--ghost {
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-primary);
}

.message-readers-modal__stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 160px));
  gap: 12px;
}

.message-readers-modal__stat {
  display: grid;
  gap: 4px;
  padding: 16px;
  border-radius: 20px;
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-secondary);
}

.message-readers-modal__stat strong {
  font-size: 24px;
  color: var(--text-primary);
}

.message-readers-modal__empty {
  display: grid;
  gap: 6px;
  place-items: center;
  min-height: 180px;
  text-align: center;
}

.message-readers-modal__empty strong {
  color: var(--text-primary);
}

.message-readers-modal__list {
  display: grid;
  gap: 10px;
}

.message-readers-modal__reader {
  padding: 14px 16px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.message-readers-modal__avatar {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 16px;
  overflow: hidden;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-weight: 700;
  flex: 0 0 auto;
}

.message-readers-modal__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.message-readers-modal__copy {
  display: grid;
  gap: 4px;
  min-width: 0;
  flex: 1 1 auto;
}

.message-readers-modal__copy strong,
.message-readers-modal__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.message-readers-modal__copy strong {
  color: var(--text-primary);
}

.message-readers-modal__meta {
  flex: 0 0 auto;
  font-size: 13px;
}

@media (max-width: 720px) {
  .message-readers-modal {
    padding: 16px;
  }

  .message-readers-modal__panel {
    padding: 20px;
  }

  .message-readers-modal__header,
  .message-readers-modal__reader {
    align-items: flex-start;
  }

  .message-readers-modal__reader {
    display: grid;
    grid-template-columns: 44px minmax(0, 1fr);
  }

  .message-readers-modal__meta {
    grid-column: 2;
  }
}
</style>
