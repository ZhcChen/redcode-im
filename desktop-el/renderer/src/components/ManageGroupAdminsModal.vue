<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface GroupAdminEntry {
  id: string;
  adminId: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
  appointedAtLabel: string | null;
}

interface GroupAdminCandidate {
  id: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
}

const props = defineProps<{
  visible: boolean;
  admins: GroupAdminEntry[];
  candidates: GroupAdminCandidate[];
  isLoading: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "appoint", payload: { memberUserIds: string[] }): void;
  (event: "remove", payload: { adminId: string; displayName: string }): void;
}>();

const searchQuery = ref("");
const selectedMemberIds = ref<string[]>([]);
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
    .filter((candidate): candidate is GroupAdminCandidate => Boolean(candidate)),
);

const resetForm = () => {
  searchQuery.value = "";
  selectedMemberIds.value = [];
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

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const handleAppoint = () => {
  if (!selectedMemberIds.value.length) {
    validationMessage.value = "请至少选择 1 位成员";
    return;
  }

  validationMessage.value = null;
  emit("appoint", {
    memberUserIds: selectedMemberIds.value,
  });
};

const handleRemove = (admin: GroupAdminEntry) => {
  if (props.isSubmitting) {
    return;
  }

  emit("remove", {
    adminId: admin.adminId,
    displayName: admin.displayName,
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
    <div v-if="props.visible" class="create-group-modal">
      <div class="create-group-modal__backdrop" @click="close" />
      <section class="create-group-modal__panel">
        <header class="create-group-modal__header">
          <div>
            <p class="create-group-modal__eyebrow">群聊</p>
            <h2>管理员设置</h2>
            <small>仅群主可任命或撤销管理员。</small>
          </div>
          <button
            type="button"
            class="create-group-modal__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="manage-group-admins__stack">
          <section class="manage-group-admins__current">
            <div class="create-group-modal__picker-header">
              <div>
                <strong>当前管理员</strong>
                <small>撤销后成员会恢复为普通成员</small>
              </div>
              <span>{{ props.admins.length }} 人</span>
            </div>

            <div v-if="props.isLoading" class="create-group-modal__empty">
              <strong>加载中</strong>
              <p>正在同步管理员列表...</p>
            </div>

            <div
              v-else-if="!props.admins.length"
              class="create-group-modal__empty create-group-modal__empty--compact"
            >
              <strong>暂无管理员</strong>
              <p>当前群还没有被任命的管理员</p>
            </div>

            <div v-else class="manage-group-admins__admin-list">
              <article
                v-for="admin in props.admins"
                :key="admin.id"
                class="manage-group-admins__admin"
              >
                <span class="create-group-modal__friend-avatar">
                  <img
                    v-if="admin.avatarUrl"
                    :src="admin.avatarUrl"
                    :alt="admin.displayName"
                  />
                  <span v-else>{{
                    buildAvatarFallback(admin.displayName)
                  }}</span>
                </span>
                <span class="manage-group-admins__admin-copy">
                  <strong>{{ admin.displayName }}</strong>
                  <small>{{ admin.subtitle || "管理员" }}</small>
                  <small v-if="admin.appointedAtLabel">
                    任命于 {{ admin.appointedAtLabel }}
                  </small>
                </span>
                <button
                  type="button"
                  class="manage-group-admins__danger"
                  :disabled="props.isSubmitting"
                  @click="handleRemove(admin)"
                >
                  撤销
                </button>
              </article>
            </div>
          </section>

          <form
            class="create-group-modal__content"
            @submit.prevent="handleAppoint"
          >
            <section class="create-group-modal__picker">
              <div class="create-group-modal__picker-header">
                <div>
                  <strong>任命管理员</strong>
                  <small>已自动过滤群主和现有管理员</small>
                </div>
                <span
                  >{{ selectedMemberIds.length }} /
                  {{ props.candidates.length }}</span
                >
              </div>

              <input
                v-model="searchQuery"
                class="create-group-modal__input"
                type="search"
                placeholder="搜索成员昵称或账号"
                :disabled="props.isLoading || props.isSubmitting"
              />

              <div class="create-group-modal__picker-grid">
                <div class="create-group-modal__list">
                  <div v-if="props.isLoading" class="create-group-modal__empty">
                    <strong>加载中</strong>
                    <p>正在同步群成员...</p>
                  </div>

                  <div
                    v-else-if="!filteredCandidates.length"
                    class="create-group-modal__empty"
                  >
                    <strong>{{
                      props.candidates.length ? "暂无匹配成员" : "暂无可任命成员"
                    }}</strong>
                    <p>
                      {{
                        props.candidates.length
                          ? "换个关键词试试"
                          : "当前群内没有可继续任命为管理员的成员"
                      }}
                    </p>
                  </div>

                  <template v-else>
                    <button
                      v-for="candidate in filteredCandidates"
                      :key="candidate.id"
                      type="button"
                      class="create-group-modal__friend"
                      :class="{
                        'create-group-modal__friend--active':
                          selectedMemberIds.includes(candidate.id),
                      }"
                      :disabled="props.isSubmitting"
                      @click="toggleCandidate(candidate.id)"
                    >
                      <span class="create-group-modal__friend-avatar">
                        <img
                          v-if="candidate.avatarUrl"
                          :src="candidate.avatarUrl"
                          :alt="candidate.displayName"
                        />
                        <span v-else>{{
                          buildAvatarFallback(candidate.displayName)
                        }}</span>
                      </span>
                      <span class="create-group-modal__friend-copy">
                        <strong>{{ candidate.displayName }}</strong>
                        <small>{{ candidate.subtitle || "暂无更多信息" }}</small>
                      </span>
                      <span class="create-group-modal__friend-check">{{
                        selectedMemberIds.includes(candidate.id) ? "已选" : "选择"
                      }}</span>
                    </button>
                  </template>
                </div>

                <aside class="create-group-modal__selected">
                  <div class="create-group-modal__picker-header">
                    <div>
                      <strong>待任命成员</strong>
                      <small>点击即可移除</small>
                    </div>
                    <span>{{ selectedCandidates.length }} 人</span>
                  </div>

                  <div
                    v-if="!selectedCandidates.length"
                    class="create-group-modal__empty create-group-modal__empty--compact"
                  >
                    <strong>尚未选择成员</strong>
                    <p>从左侧列表勾选要任命的成员</p>
                  </div>

                  <div v-else class="create-group-modal__selected-list">
                    <button
                      v-for="candidate in selectedCandidates"
                      :key="candidate.id"
                      type="button"
                      class="create-group-modal__member-chip"
                      :disabled="props.isSubmitting"
                      @click="removeCandidate(candidate.id)"
                    >
                      <span class="create-group-modal__member-avatar">
                        <img
                          v-if="candidate.avatarUrl"
                          :src="candidate.avatarUrl"
                          :alt="candidate.displayName"
                        />
                        <span v-else>{{
                          buildAvatarFallback(candidate.displayName)
                        }}</span>
                      </span>
                      <span>{{ candidate.displayName }}</span>
                    </button>
                  </div>
                </aside>
              </div>
            </section>

            <p v-if="validationMessage" class="create-group-modal__error">
              {{ validationMessage }}
            </p>

            <footer class="create-group-modal__footer">
              <button
                type="button"
                class="create-group-modal__secondary"
                :disabled="props.isSubmitting"
                @click="close"
              >
                取消
              </button>
              <button
                type="submit"
                class="create-group-modal__primary"
                :disabled="props.isLoading || props.isSubmitting"
              >
                {{ props.isSubmitting ? "提交中..." : "任命管理员" }}
              </button>
            </footer>
          </form>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.create-group-modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 24px;
}

.create-group-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.create-group-modal__panel {
  position: relative;
  z-index: 1;
  width: min(960px, 100%);
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

.create-group-modal__header,
.create-group-modal__picker-header,
.create-group-modal__footer,
.create-group-modal__friend,
.create-group-modal__member-chip,
.manage-group-admins__admin {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.create-group-modal__header {
  align-items: flex-start;
  margin-bottom: 20px;
}

.create-group-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.create-group-modal__header h2,
.create-group-modal__picker-header strong,
.create-group-modal__empty strong,
.manage-group-admins__admin-copy strong {
  margin: 0;
  color: var(--text-primary);
}

.create-group-modal__header small,
.create-group-modal__picker-header small,
.create-group-modal__empty p,
.create-group-modal__friend-copy small,
.manage-group-admins__admin-copy small {
  color: var(--text-secondary);
}

.create-group-modal__close,
.create-group-modal__secondary,
.create-group-modal__primary,
.create-group-modal__member-chip,
.create-group-modal__friend,
.manage-group-admins__danger {
  border: 1px solid transparent;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.create-group-modal__close,
.create-group-modal__secondary,
.create-group-modal__primary {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
}

.create-group-modal__close,
.create-group-modal__secondary {
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.create-group-modal__primary {
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
}

.create-group-modal__content,
.manage-group-admins__stack,
.manage-group-admins__current {
  display: grid;
  gap: 18px;
}

.manage-group-admins__current {
  padding: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.76);
}

.manage-group-admins__admin-list,
.create-group-modal__selected-list {
  display: grid;
  gap: 10px;
}

.create-group-modal__input {
  width: 100%;
  min-height: 46px;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  color: var(--text-primary);
}

.create-group-modal__input:focus {
  outline: none;
  border-color: rgba(0, 155, 143, 0.36);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.12);
}

.create-group-modal__picker {
  display: grid;
  gap: 14px;
}

.create-group-modal__picker-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.25fr) minmax(260px, 0.75fr);
  gap: 16px;
}

.create-group-modal__list,
.create-group-modal__selected {
  display: grid;
  gap: 12px;
  min-height: 320px;
  padding: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.76);
}

.create-group-modal__list {
  align-content: start;
  overflow: auto;
}

.create-group-modal__selected,
.manage-group-admins__current {
  align-content: start;
}

.create-group-modal__empty {
  display: grid;
  gap: 6px;
  place-items: center;
  min-height: 180px;
  text-align: center;
}

.create-group-modal__empty--compact {
  min-height: 120px;
}

.create-group-modal__friend,
.manage-group-admins__admin {
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(241, 245, 249, 0.82);
  text-align: left;
}

.create-group-modal__friend:hover,
.create-group-modal__member-chip:hover,
.create-group-modal__close:hover,
.create-group-modal__secondary:hover,
.create-group-modal__primary:hover,
.manage-group-admins__danger:hover {
  transform: translateY(-1px);
}

.create-group-modal__friend--active {
  border-color: rgba(0, 155, 143, 0.28);
  background: rgba(0, 194, 179, 0.12);
}

.create-group-modal__friend-avatar,
.create-group-modal__member-avatar {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  border-radius: 14px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-weight: 700;
  overflow: hidden;
}

.create-group-modal__friend-avatar img,
.create-group-modal__member-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.create-group-modal__friend-copy,
.manage-group-admins__admin-copy {
  display: grid;
  gap: 4px;
  flex: 1;
  min-width: 0;
}

.create-group-modal__friend-copy strong,
.create-group-modal__friend-copy small,
.create-group-modal__friend-check,
.manage-group-admins__admin-copy strong,
.manage-group-admins__admin-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.create-group-modal__friend-check {
  color: var(--primary-color-strong);
  font-size: 13px;
  font-weight: 700;
}

.create-group-modal__member-chip {
  justify-content: flex-start;
  padding: 10px 12px;
  border-radius: 16px;
  background: rgba(241, 245, 249, 0.82);
  color: var(--text-primary);
}

.create-group-modal__member-chip span:last-child {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.manage-group-admins__danger {
  height: 38px;
  padding: 0 14px;
  border-radius: 999px;
  background: rgba(220, 38, 38, 0.12);
  color: #b91c1c;
}

.create-group-modal__error {
  margin: 0;
  color: #dc2626;
  font-size: 13px;
  font-weight: 600;
}

.create-group-modal__footer {
  justify-content: flex-end;
  padding-top: 6px;
}

.create-group-modal__close:disabled,
.create-group-modal__secondary:disabled,
.create-group-modal__primary:disabled,
.create-group-modal__friend:disabled,
.create-group-modal__member-chip:disabled,
.manage-group-admins__danger:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

@media (max-width: 900px) {
  .create-group-modal {
    padding: 16px;
  }

  .create-group-modal__panel {
    padding: 20px;
  }

  .create-group-modal__picker-grid {
    grid-template-columns: 1fr;
  }

  .create-group-modal__list,
  .create-group-modal__selected {
    min-height: 220px;
  }
}

@media (max-width: 640px) {
  .create-group-modal__header,
  .create-group-modal__footer,
  .manage-group-admins__admin {
    flex-direction: column;
    align-items: stretch;
  }

  .create-group-modal__close,
  .create-group-modal__secondary,
  .create-group-modal__primary,
  .manage-group-admins__danger {
    width: 100%;
    justify-content: center;
  }
}
</style>
