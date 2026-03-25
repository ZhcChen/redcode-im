<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface GroupMuteEntry {
  id: string;
  userId: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
  reason: string | null;
  mutedAtLabel: string | null;
  muteUntilLabel: string | null;
  mutedByLabel: string | null;
  isPermanent: boolean;
}

interface GroupMuteCandidate {
  id: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
}

const props = defineProps<{
  visible: boolean;
  mutes: GroupMuteEntry[];
  candidates: GroupMuteCandidate[];
  isLoading: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "mute", payload: {
    memberUserIds: string[];
    durationHours: number;
    reason?: string;
  }): void;
  (event: "unmute", payload: { userId: string; displayName: string }): void;
}>();

const durationOptions = [
  { value: 1, label: "1 小时" },
  { value: 6, label: "6 小时" },
  { value: 12, label: "12 小时" },
  { value: 24, label: "1 天" },
  { value: 72, label: "3 天" },
  { value: 168, label: "7 天" },
  { value: 0, label: "永久" },
];

const searchQuery = ref("");
const selectedMemberIds = ref<string[]>([]);
const durationHours = ref(24);
const reason = ref("");
const validationMessage = ref<string | null>(null);

const filteredCandidates = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();
  if (!keyword) {
    return props.candidates;
  }

  return props.candidates.filter((candidate) => {
    const displayName = candidate.displayName.toLowerCase();
    const subtitle = candidate.subtitle?.toLowerCase() ?? "";
    return displayName.includes(keyword) || subtitle.includes(keyword);
  });
});

const selectedCandidates = computed(() =>
  selectedMemberIds.value
    .map((memberId) =>
      props.candidates.find((candidate) => candidate.id === memberId),
    )
    .filter((candidate): candidate is GroupMuteCandidate => Boolean(candidate)),
);

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const resetForm = () => {
  searchQuery.value = "";
  selectedMemberIds.value = [];
  durationHours.value = 24;
  reason.value = "";
  validationMessage.value = null;
};

const close = () => {
  if (props.isSubmitting) {
    return;
  }
  emit("update:visible", false);
};

const toggleCandidate = (candidateId: string) => {
  const exists = selectedMemberIds.value.includes(candidateId);
  selectedMemberIds.value = exists
    ? selectedMemberIds.value.filter((id) => id !== candidateId)
    : [...selectedMemberIds.value, candidateId];
  validationMessage.value = null;
};

const removeCandidate = (candidateId: string) => {
  selectedMemberIds.value = selectedMemberIds.value.filter(
    (id) => id !== candidateId,
  );
};

const handleMute = () => {
  if (!selectedMemberIds.value.length) {
    validationMessage.value = "请至少选择 1 位成员";
    return;
  }

  validationMessage.value = null;
  emit("mute", {
    memberUserIds: selectedMemberIds.value,
    durationHours: durationHours.value,
    reason: reason.value.trim() || undefined,
  });
};

const handleUnmute = (entry: GroupMuteEntry) => {
  if (props.isSubmitting) {
    return;
  }

  emit("unmute", {
    userId: entry.userId,
    displayName: entry.displayName,
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
    <div v-if="props.visible" class="manage-group-mutes">
      <div class="manage-group-mutes__backdrop" @click="close" />
      <section class="manage-group-mutes__panel">
        <header class="manage-group-mutes__header">
          <div>
            <p class="manage-group-mutes__eyebrow">群聊</p>
            <h2>禁言管理</h2>
            <small>群主或管理员可以禁言普通成员并解除禁言。</small>
          </div>
          <button
            type="button"
            class="manage-group-mutes__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="manage-group-mutes__stack">
          <section class="manage-group-mutes__current">
            <div class="manage-group-mutes__section-head">
              <div>
                <strong>当前禁言</strong>
                <small>这里只展示仍在生效中的禁言成员</small>
              </div>
              <span>{{ props.mutes.length }} 人</span>
            </div>

            <div v-if="props.isLoading" class="manage-group-mutes__empty">
              <strong>加载中</strong>
              <p>正在同步禁言列表...</p>
            </div>

            <div
              v-else-if="!props.mutes.length"
              class="manage-group-mutes__empty manage-group-mutes__empty--compact"
            >
              <strong>暂无禁言成员</strong>
              <p>当前群还没有生效中的成员禁言。</p>
            </div>

            <div v-else class="manage-group-mutes__mute-list">
              <article
                v-for="entry in props.mutes"
                :key="entry.id"
                class="manage-group-mutes__mute-item"
              >
                <span class="manage-group-mutes__avatar">
                  <img
                    v-if="entry.avatarUrl"
                    :src="entry.avatarUrl"
                    :alt="entry.displayName"
                  />
                  <span v-else>{{
                    buildAvatarFallback(entry.displayName)
                  }}</span>
                </span>
                <span class="manage-group-mutes__mute-copy">
                  <strong>{{ entry.displayName }}</strong>
                  <small>{{ entry.subtitle || "普通成员" }}</small>
                  <small v-if="entry.reason">原因：{{ entry.reason }}</small>
                  <small v-if="entry.mutedByLabel">
                    操作人：{{ entry.mutedByLabel }}
                  </small>
                  <small v-if="entry.mutedAtLabel">
                    生效时间：{{ entry.mutedAtLabel }}
                  </small>
                  <small>
                    {{ entry.isPermanent ? "解禁时间：永久" : `解禁时间：${entry.muteUntilLabel || "暂无"}` }}
                  </small>
                </span>
                <button
                  type="button"
                  class="manage-group-mutes__danger"
                  :disabled="props.isSubmitting"
                  @click="handleUnmute(entry)"
                >
                  解除
                </button>
              </article>
            </div>
          </section>

          <form class="manage-group-mutes__form" @submit.prevent="handleMute">
            <section class="manage-group-mutes__picker">
              <div class="manage-group-mutes__section-head">
                <div>
                  <strong>新增禁言</strong>
                  <small>已自动过滤群主、管理员和当前已禁言成员</small>
                </div>
                <span
                  >{{ selectedMemberIds.length }} /
                  {{ props.candidates.length }}</span
                >
              </div>

              <input
                v-model="searchQuery"
                class="manage-group-mutes__input"
                type="search"
                placeholder="搜索成员昵称或账号"
                :disabled="props.isLoading || props.isSubmitting"
              />

              <div class="manage-group-mutes__picker-grid">
                <div class="manage-group-mutes__list">
                  <div v-if="props.isLoading" class="manage-group-mutes__empty">
                    <strong>加载中</strong>
                    <p>正在同步群成员...</p>
                  </div>

                  <div
                    v-else-if="!filteredCandidates.length"
                    class="manage-group-mutes__empty"
                  >
                    <strong>{{
                      props.candidates.length ? "暂无匹配成员" : "暂无可禁言成员"
                    }}</strong>
                    <p>
                      {{
                        props.candidates.length
                          ? "换个关键词试试"
                          : "当前群内没有可继续禁言的普通成员"
                      }}
                    </p>
                  </div>

                  <template v-else>
                    <button
                      v-for="candidate in filteredCandidates"
                      :key="candidate.id"
                      type="button"
                      class="manage-group-mutes__candidate"
                      :class="{
                        'manage-group-mutes__candidate--active':
                          selectedMemberIds.includes(candidate.id),
                      }"
                      :disabled="props.isSubmitting"
                      @click="toggleCandidate(candidate.id)"
                    >
                      <span class="manage-group-mutes__avatar">
                        <img
                          v-if="candidate.avatarUrl"
                          :src="candidate.avatarUrl"
                          :alt="candidate.displayName"
                        />
                        <span v-else>{{
                          buildAvatarFallback(candidate.displayName)
                        }}</span>
                      </span>
                      <span class="manage-group-mutes__candidate-copy">
                        <strong>{{ candidate.displayName }}</strong>
                        <small>{{ candidate.subtitle || "普通成员" }}</small>
                      </span>
                    </button>
                  </template>
                </div>

                <aside class="manage-group-mutes__selected">
                  <div>
                    <strong>已选成员</strong>
                    <small>支持一次禁言多位成员</small>
                  </div>
                  <div
                    v-if="!selectedCandidates.length"
                    class="manage-group-mutes__selected-empty"
                  >
                    还没有选择成员
                  </div>
                  <div v-else class="manage-group-mutes__selected-list">
                    <button
                      v-for="candidate in selectedCandidates"
                      :key="candidate.id"
                      type="button"
                      class="manage-group-mutes__selected-chip"
                      :disabled="props.isSubmitting"
                      @click="removeCandidate(candidate.id)"
                    >
                      <span>{{ candidate.displayName }}</span>
                      <small>移除</small>
                    </button>
                  </div>
                </aside>
              </div>
            </section>

            <section class="manage-group-mutes__config">
              <label class="manage-group-mutes__field">
                <span>禁言时长</span>
                <select v-model="durationHours" :disabled="props.isSubmitting">
                  <option
                    v-for="option in durationOptions"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
              </label>

              <label class="manage-group-mutes__field manage-group-mutes__field--grow">
                <span>禁言原因</span>
                <input
                  v-model="reason"
                  type="text"
                  maxlength="100"
                  placeholder="可选，最多 100 字"
                  :disabled="props.isSubmitting"
                />
              </label>
            </section>

            <p v-if="validationMessage" class="manage-group-mutes__validation">
              {{ validationMessage }}
            </p>

            <div class="manage-group-mutes__footer">
              <small>
                {{ durationHours === 0 ? "将以永久禁言方式提交" : `将按 ${durationOptions.find((option) => option.value === durationHours)?.label || "预设时长"} 提交` }}
              </small>
              <button
                type="submit"
                class="manage-group-mutes__submit"
                :disabled="props.isLoading || props.isSubmitting"
              >
                {{ props.isSubmitting ? "提交中..." : "确认禁言" }}
              </button>
            </div>
          </form>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.manage-group-mutes {
  position: fixed;
  inset: 0;
  z-index: 52;
  display: grid;
  place-items: center;
  padding: 24px;
}

.manage-group-mutes__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.manage-group-mutes__panel {
  position: relative;
  z-index: 1;
  width: min(980px, 100%);
  max-height: min(88vh, 920px);
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

.manage-group-mutes__header,
.manage-group-mutes__section-head,
.manage-group-mutes__mute-item,
.manage-group-mutes__footer,
.manage-group-mutes__config {
  display: flex;
  gap: 12px;
}

.manage-group-mutes__header,
.manage-group-mutes__section-head,
.manage-group-mutes__footer,
.manage-group-mutes__config {
  align-items: center;
  justify-content: space-between;
}

.manage-group-mutes__header {
  align-items: flex-start;
  margin-bottom: 20px;
}

.manage-group-mutes__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.manage-group-mutes__header h2,
.manage-group-mutes__empty strong,
.manage-group-mutes__candidate-copy strong,
.manage-group-mutes__mute-copy strong,
.manage-group-mutes__section-head strong {
  margin: 0;
  color: var(--text-primary);
}

.manage-group-mutes__header small,
.manage-group-mutes__empty p,
.manage-group-mutes__candidate-copy small,
.manage-group-mutes__mute-copy small,
.manage-group-mutes__section-head small,
.manage-group-mutes__footer small,
.manage-group-mutes__selected small {
  color: var(--text-secondary);
}

.manage-group-mutes__close,
.manage-group-mutes__danger,
.manage-group-mutes__submit,
.manage-group-mutes__candidate,
.manage-group-mutes__selected-chip {
  border: 1px solid transparent;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease,
    box-shadow 0.18s ease;
}

.manage-group-mutes__close {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.manage-group-mutes__stack {
  display: grid;
  gap: 18px;
}

.manage-group-mutes__current,
.manage-group-mutes__picker,
.manage-group-mutes__form {
  display: grid;
  gap: 14px;
}

.manage-group-mutes__current,
.manage-group-mutes__form {
  padding: 18px;
  border-radius: 22px;
  background: rgba(248, 250, 252, 0.86);
  border: 1px solid rgba(148, 163, 184, 0.18);
}

.manage-group-mutes__mute-list,
.manage-group-mutes__selected-list {
  display: grid;
  gap: 10px;
}

.manage-group-mutes__mute-item,
.manage-group-mutes__candidate {
  align-items: center;
  width: 100%;
  padding: 14px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.92);
  text-align: left;
}

.manage-group-mutes__candidate {
  justify-content: flex-start;
}

.manage-group-mutes__candidate:hover,
.manage-group-mutes__selected-chip:hover,
.manage-group-mutes__close:hover,
.manage-group-mutes__danger:hover,
.manage-group-mutes__submit:hover {
  transform: translateY(-1px);
}

.manage-group-mutes__candidate--active {
  border-color: rgba(14, 116, 144, 0.24);
  background: rgba(207, 250, 254, 0.8);
  box-shadow: 0 12px 24px rgba(8, 145, 178, 0.12);
}

.manage-group-mutes__avatar {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  border-radius: 16px;
  overflow: hidden;
  background: linear-gradient(135deg, #0ea5e9, #0284c7);
  color: #ffffff;
  font-weight: 700;
}

.manage-group-mutes__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.manage-group-mutes__mute-copy,
.manage-group-mutes__candidate-copy,
.manage-group-mutes__selected {
  min-width: 0;
  display: grid;
  gap: 4px;
}

.manage-group-mutes__mute-copy,
.manage-group-mutes__candidate-copy {
  flex: 1;
}

.manage-group-mutes__danger {
  height: 38px;
  padding: 0 16px;
  border-radius: 999px;
  background: rgba(239, 68, 68, 0.12);
  color: #b91c1c;
}

.manage-group-mutes__input,
.manage-group-mutes__field select,
.manage-group-mutes__field input {
  width: 100%;
  border: 1px solid rgba(148, 163, 184, 0.24);
  background: rgba(255, 255, 255, 0.94);
  color: var(--text-primary);
  outline: none;
}

.manage-group-mutes__input,
.manage-group-mutes__field input {
  min-height: 46px;
  padding: 0 14px;
  border-radius: 16px;
}

.manage-group-mutes__field select {
  min-height: 46px;
  padding: 0 14px;
  border-radius: 16px;
}

.manage-group-mutes__picker-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(240px, 0.9fr);
  gap: 14px;
}

.manage-group-mutes__list,
.manage-group-mutes__selected {
  min-height: 260px;
  padding: 14px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid rgba(148, 163, 184, 0.18);
}

.manage-group-mutes__list {
  display: grid;
  gap: 10px;
  align-content: start;
}

.manage-group-mutes__selected-empty {
  display: grid;
  place-items: center;
  min-height: 120px;
  border-radius: 16px;
  background: rgba(241, 245, 249, 0.86);
  color: var(--text-secondary);
  text-align: center;
}

.manage-group-mutes__selected-chip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
  padding: 12px 14px;
  border-radius: 16px;
  background: rgba(224, 242, 254, 0.72);
  color: #0f172a;
}

.manage-group-mutes__field {
  display: grid;
  gap: 8px;
  flex: 0 0 180px;
}

.manage-group-mutes__field span {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
}

.manage-group-mutes__field--grow {
  flex: 1;
}

.manage-group-mutes__validation {
  margin: 0;
  color: #b91c1c;
  font-size: 13px;
}

.manage-group-mutes__submit {
  height: 44px;
  padding: 0 18px;
  border-radius: 999px;
  background: linear-gradient(135deg, #0f766e, #0ea5e9);
  color: #ffffff;
}

.manage-group-mutes__empty {
  display: grid;
  place-items: center;
  min-height: 180px;
  border-radius: 18px;
  background: rgba(241, 245, 249, 0.86);
  text-align: center;
}

.manage-group-mutes__empty--compact {
  min-height: 120px;
}

@media (max-width: 900px) {
  .manage-group-mutes {
    padding: 16px;
  }

  .manage-group-mutes__panel {
    padding: 20px;
  }

  .manage-group-mutes__picker-grid {
    grid-template-columns: 1fr;
  }

  .manage-group-mutes__config,
  .manage-group-mutes__footer {
    flex-direction: column;
    align-items: stretch;
  }

  .manage-group-mutes__field {
    flex: 1 1 auto;
  }
}
</style>
