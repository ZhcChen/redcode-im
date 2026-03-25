<script setup lang="ts">
interface GroupJoinRequestEntry {
  id: string;
  applicantId: string;
  displayName: string;
  subtitle: string | null;
  message: string | null;
  status: "pending" | "approved" | "rejected";
  createdAtLabel: string | null;
  reviewedAtLabel: string | null;
  reviewMessage: string | null;
}

const props = defineProps<{
  visible: boolean;
  requests: GroupJoinRequestEntry[];
  isLoading: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "review", payload: {
    requestId: string;
    status: "approved" | "rejected";
    displayName: string;
  }): void;
}>();

const close = () => {
  if (props.isSubmitting) {
    return;
  }
  emit("update:visible", false);
};

const statusLabelMap: Record<GroupJoinRequestEntry["status"], string> = {
  pending: "待审核",
  approved: "已通过",
  rejected: "已拒绝",
};

const handleReview = (
  request: GroupJoinRequestEntry,
  status: "approved" | "rejected",
) => {
  if (props.isSubmitting || request.status !== "pending") {
    return;
  }

  emit("review", {
    requestId: request.id,
    status,
    displayName: request.displayName,
  });
};
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="join-requests-modal">
      <div class="join-requests-modal__backdrop" @click="close" />
      <section class="join-requests-modal__panel">
        <header class="join-requests-modal__header">
          <div>
            <p class="join-requests-modal__eyebrow">群聊</p>
            <h2>入群审核</h2>
            <small>群主或管理员可以审核当前群的入群申请。</small>
          </div>
          <button
            type="button"
            class="join-requests-modal__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div v-if="props.isLoading" class="join-requests-modal__empty">
          <strong>加载中</strong>
          <p>正在同步入群申请列表...</p>
        </div>

        <div
          v-else-if="!props.requests.length"
          class="join-requests-modal__empty"
        >
          <strong>暂无入群申请</strong>
          <p>当前群还没有待处理或历史审核记录。</p>
        </div>

        <div v-else class="join-requests-modal__list">
          <article
            v-for="request in props.requests"
            :key="request.id"
            class="join-requests-modal__item"
          >
            <div class="join-requests-modal__avatar">
              {{ request.displayName.slice(0, 1).toUpperCase() || "?" }}
            </div>
            <div class="join-requests-modal__copy">
              <div class="join-requests-modal__topline">
                <strong>{{ request.displayName }}</strong>
                <span
                  class="join-requests-modal__status"
                  :class="`join-requests-modal__status--${request.status}`"
                >
                  {{ statusLabelMap[request.status] }}
                </span>
              </div>
              <small v-if="request.subtitle">{{ request.subtitle }}</small>
              <p v-if="request.message" class="join-requests-modal__message">
                申请理由：{{ request.message }}
              </p>
              <small>申请时间：{{ request.createdAtLabel || "暂无" }}</small>
              <small v-if="request.reviewedAtLabel">
                审核时间：{{ request.reviewedAtLabel }}
              </small>
              <small v-if="request.reviewMessage">
                审核备注：{{ request.reviewMessage }}
              </small>
            </div>
            <div
              v-if="request.status === 'pending'"
              class="join-requests-modal__actions"
            >
              <button
                type="button"
                class="join-requests-modal__approve"
                :disabled="props.isSubmitting"
                @click="handleReview(request, 'approved')"
              >
                通过
              </button>
              <button
                type="button"
                class="join-requests-modal__reject"
                :disabled="props.isSubmitting"
                @click="handleReview(request, 'rejected')"
              >
                拒绝
              </button>
            </div>
          </article>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.join-requests-modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 24px;
}

.join-requests-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.join-requests-modal__panel {
  position: relative;
  z-index: 1;
  width: min(840px, 100%);
  max-height: min(86vh, 860px);
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

.join-requests-modal__header,
.join-requests-modal__item,
.join-requests-modal__actions {
  display: flex;
  gap: 12px;
}

.join-requests-modal__header {
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 20px;
}

.join-requests-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.join-requests-modal__header h2,
.join-requests-modal__empty strong,
.join-requests-modal__copy strong {
  margin: 0;
  color: var(--text-primary);
}

.join-requests-modal__header small,
.join-requests-modal__copy small,
.join-requests-modal__empty p {
  color: var(--text-secondary);
}

.join-requests-modal__close,
.join-requests-modal__approve,
.join-requests-modal__reject {
  border: 1px solid transparent;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.join-requests-modal__close {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.join-requests-modal__list {
  display: grid;
  gap: 12px;
}

.join-requests-modal__item {
  align-items: flex-start;
  padding: 16px;
  border-radius: 20px;
  background: rgba(241, 245, 249, 0.82);
}

.join-requests-modal__avatar {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  border-radius: 16px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-weight: 700;
}

.join-requests-modal__copy {
  flex: 1;
  min-width: 0;
  display: grid;
  gap: 6px;
}

.join-requests-modal__topline {
  display: flex;
  align-items: center;
  gap: 10px;
}

.join-requests-modal__message {
  margin: 0;
  color: var(--text-primary);
  line-height: 1.5;
  word-break: break-word;
}

.join-requests-modal__status {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 64px;
  height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
}

.join-requests-modal__status--pending {
  background: rgba(245, 158, 11, 0.14);
  color: #b45309;
}

.join-requests-modal__status--approved {
  background: rgba(34, 197, 94, 0.14);
  color: #15803d;
}

.join-requests-modal__status--rejected {
  background: rgba(220, 38, 38, 0.12);
  color: #b91c1c;
}

.join-requests-modal__actions {
  align-items: center;
  flex-shrink: 0;
}

.join-requests-modal__approve,
.join-requests-modal__reject {
  height: 38px;
  padding: 0 14px;
  border-radius: 999px;
}

.join-requests-modal__approve {
  background: rgba(34, 197, 94, 0.14);
  color: #15803d;
}

.join-requests-modal__reject {
  background: rgba(220, 38, 38, 0.12);
  color: #b91c1c;
}

.join-requests-modal__empty {
  display: grid;
  gap: 6px;
  place-items: center;
  min-height: 220px;
  text-align: center;
}

.join-requests-modal__close:hover,
.join-requests-modal__approve:hover,
.join-requests-modal__reject:hover {
  transform: translateY(-1px);
}

.join-requests-modal__close:disabled,
.join-requests-modal__approve:disabled,
.join-requests-modal__reject:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

@media (max-width: 720px) {
  .join-requests-modal {
    padding: 16px;
  }

  .join-requests-modal__panel {
    padding: 20px;
  }

  .join-requests-modal__header,
  .join-requests-modal__item {
    flex-direction: column;
  }

  .join-requests-modal__actions,
  .join-requests-modal__close {
    width: 100%;
  }

  .join-requests-modal__approve,
  .join-requests-modal__reject,
  .join-requests-modal__close {
    justify-content: center;
    width: 100%;
  }
}
</style>
