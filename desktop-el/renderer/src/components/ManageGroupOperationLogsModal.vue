<script setup lang="ts">
interface GroupOperationLogEntry {
  id: string;
  createdAtLabel: string | null;
  operatorLabel: string;
  actionText: string;
  targetLabel: string | null;
}

const props = defineProps<{
  visible: boolean;
  logs: GroupOperationLogEntry[];
  isLoading: boolean;
  isLoadingMore: boolean;
  hasMore: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "load-more"): void;
}>();

const close = () => {
  if (props.isLoadingMore) {
    return;
  }
  emit("update:visible", false);
};

const handleLoadMore = () => {
  if (!props.hasMore || props.isLoading || props.isLoadingMore) {
    return;
  }
  emit("load-more");
};
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="manage-group-operation-logs">
      <div class="manage-group-operation-logs__backdrop" @click="close" />
      <section class="manage-group-operation-logs__panel">
        <header class="manage-group-operation-logs__header">
          <div>
            <p class="manage-group-operation-logs__eyebrow">群聊</p>
            <h2>操作日志</h2>
            <small>展示最近的群管理操作，按后端返回顺序持续追加。</small>
          </div>
          <button
            type="button"
            class="manage-group-operation-logs__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div v-if="props.isLoading && !props.logs.length" class="manage-group-operation-logs__empty">
          <strong>加载中</strong>
          <p>正在同步操作日志...</p>
        </div>

        <div
          v-else-if="!props.logs.length"
          class="manage-group-operation-logs__empty manage-group-operation-logs__empty--compact"
        >
          <strong>暂无操作日志</strong>
          <p>当前群还没有可展示的管理操作记录。</p>
        </div>

        <div v-else class="manage-group-operation-logs__list">
          <article
            v-for="entry in props.logs"
            :key="entry.id"
            class="manage-group-operation-logs__item"
          >
            <div class="manage-group-operation-logs__time">
              {{ entry.createdAtLabel || "暂无时间" }}
            </div>
            <div class="manage-group-operation-logs__content">
              <span class="manage-group-operation-logs__operator">{{
                entry.operatorLabel
              }}</span>
              <span class="manage-group-operation-logs__action">{{
                entry.actionText
              }}</span>
              <span
                v-if="entry.targetLabel"
                class="manage-group-operation-logs__target"
              >
                {{ entry.targetLabel }}
              </span>
            </div>
          </article>
        </div>

        <div
          v-if="props.hasMore || props.isLoadingMore"
          class="manage-group-operation-logs__footer"
        >
          <button
            type="button"
            class="manage-group-operation-logs__load-more"
            :disabled="props.isLoading || props.isLoadingMore"
            @click="handleLoadMore"
          >
            {{ props.isLoadingMore ? "加载中..." : "加载更多" }}
          </button>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.manage-group-operation-logs {
  position: fixed;
  inset: 0;
  z-index: 52;
  display: grid;
  place-items: center;
  padding: 24px;
}

.manage-group-operation-logs__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.manage-group-operation-logs__panel {
  position: relative;
  z-index: 1;
  width: min(860px, 100%);
  max-height: min(86vh, 900px);
  overflow: auto;
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

.manage-group-operation-logs__header,
.manage-group-operation-logs__item {
  display: flex;
  gap: 14px;
}

.manage-group-operation-logs__header {
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 20px;
}

.manage-group-operation-logs__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.manage-group-operation-logs__header h2,
.manage-group-operation-logs__empty strong {
  margin: 0;
  color: var(--text-primary);
}

.manage-group-operation-logs__header small,
.manage-group-operation-logs__empty p {
  color: var(--text-secondary);
}

.manage-group-operation-logs__close,
.manage-group-operation-logs__load-more {
  border: 1px solid transparent;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.manage-group-operation-logs__close {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.manage-group-operation-logs__close:hover,
.manage-group-operation-logs__load-more:hover {
  transform: translateY(-1px);
}

.manage-group-operation-logs__list {
  display: grid;
  gap: 10px;
}

.manage-group-operation-logs__item {
  align-items: flex-start;
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(248, 250, 252, 0.88);
}

.manage-group-operation-logs__time {
  min-width: 150px;
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.5;
}

.manage-group-operation-logs__content {
  flex: 1;
  min-width: 0;
  color: var(--text-primary);
  line-height: 1.6;
}

.manage-group-operation-logs__operator,
.manage-group-operation-logs__target {
  color: var(--primary-color-strong);
  font-weight: 600;
}

.manage-group-operation-logs__action {
  margin: 0 6px;
  color: var(--text-secondary);
}

.manage-group-operation-logs__footer {
  display: flex;
  justify-content: center;
  margin-top: 18px;
}

.manage-group-operation-logs__load-more {
  height: 42px;
  padding: 0 20px;
  border-radius: 999px;
  background: rgba(14, 116, 144, 0.1);
  color: #0f766e;
}

.manage-group-operation-logs__empty {
  display: grid;
  place-items: center;
  min-height: 180px;
  border-radius: 18px;
  background: rgba(241, 245, 249, 0.86);
  text-align: center;
}

.manage-group-operation-logs__empty--compact {
  min-height: 120px;
}

@media (max-width: 900px) {
  .manage-group-operation-logs {
    padding: 16px;
  }

  .manage-group-operation-logs__panel {
    padding: 20px;
  }

  .manage-group-operation-logs__header,
  .manage-group-operation-logs__item {
    flex-direction: column;
  }

  .manage-group-operation-logs__time {
    min-width: 0;
  }
}
</style>
