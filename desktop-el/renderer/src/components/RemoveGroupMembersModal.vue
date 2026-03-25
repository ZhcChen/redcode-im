<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface GroupMemberOption {
  id: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
}

const props = defineProps<{
  visible: boolean;
  members: GroupMemberOption[];
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "submit", payload: { memberUserIds: string[] }): void;
}>();

const searchQuery = ref("");
const selectedMemberIds = ref<string[]>([]);
const validationMessage = ref<string | null>(null);

const filteredMembers = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();
  if (!keyword) {
    return props.members;
  }

  return props.members.filter((member) => {
    const displayName = member.displayName.toLowerCase();
    const subtitle = member.subtitle?.toLowerCase() ?? "";
    return displayName.includes(keyword) || subtitle.includes(keyword);
  });
});

const selectedMembers = computed(() =>
  selectedMemberIds.value
    .map((memberId) => props.members.find((member) => member.id === memberId))
    .filter((member): member is GroupMemberOption => Boolean(member)),
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

const toggleMember = (memberId: string) => {
  const exists = selectedMemberIds.value.includes(memberId);
  selectedMemberIds.value = exists
    ? selectedMemberIds.value.filter((id) => id !== memberId)
    : [...selectedMemberIds.value, memberId];
  validationMessage.value = null;
};

const removeMember = (memberId: string) => {
  selectedMemberIds.value = selectedMemberIds.value.filter(
    (id) => id !== memberId,
  );
};

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const handleSubmit = () => {
  if (!selectedMemberIds.value.length) {
    validationMessage.value = "请至少选择 1 位成员";
    return;
  }

  validationMessage.value = null;
  emit("submit", {
    memberUserIds: selectedMemberIds.value,
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
            <h2>删除群成员</h2>
            <small>选择要从当前群聊移除的成员。</small>
          </div>
          <button
            type="button"
            class="create-group-modal__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <form
          class="create-group-modal__content"
          @submit.prevent="handleSubmit"
        >
          <section class="create-group-modal__picker">
            <div class="create-group-modal__picker-header">
              <div>
                <strong>选择成员</strong>
                <small>已自动过滤群主和当前账号</small>
              </div>
              <span
                >{{ selectedMemberIds.length }} /
                {{ props.members.length }}</span
              >
            </div>

            <input
              v-model="searchQuery"
              class="create-group-modal__input"
              type="search"
              placeholder="搜索成员昵称或账号"
              :disabled="props.isSubmitting"
            />

            <div class="create-group-modal__picker-grid">
              <div class="create-group-modal__list">
                <div v-if="!filteredMembers.length" class="create-group-modal__empty">
                  <strong>{{
                    props.members.length ? "暂无匹配成员" : "暂无可移除成员"
                  }}</strong>
                  <p>
                    {{
                      props.members.length
                        ? "换个关键词试试"
                        : "当前没有可由你移除的成员"
                    }}
                  </p>
                </div>

                <template v-else>
                  <button
                    v-for="member in filteredMembers"
                    :key="member.id"
                    type="button"
                    class="create-group-modal__friend"
                    :class="{
                      'create-group-modal__friend--active':
                        selectedMemberIds.includes(member.id),
                    }"
                    :disabled="props.isSubmitting"
                    @click="toggleMember(member.id)"
                  >
                    <span class="create-group-modal__friend-avatar">
                      <img
                        v-if="member.avatarUrl"
                        :src="member.avatarUrl"
                        :alt="member.displayName"
                      />
                      <span v-else>{{
                        buildAvatarFallback(member.displayName)
                      }}</span>
                    </span>
                    <span class="create-group-modal__friend-copy">
                      <strong>{{ member.displayName }}</strong>
                      <small>{{ member.subtitle || "暂无更多信息" }}</small>
                    </span>
                    <span class="create-group-modal__friend-check">{{
                      selectedMemberIds.includes(member.id) ? "已选" : "选择"
                    }}</span>
                  </button>
                </template>
              </div>

              <aside class="create-group-modal__selected">
                <div class="create-group-modal__picker-header">
                  <div>
                    <strong>待删除成员</strong>
                    <small>点击即可移除</small>
                  </div>
                  <span>{{ selectedMembers.length }} 人</span>
                </div>

                <div
                  v-if="!selectedMembers.length"
                  class="create-group-modal__empty create-group-modal__empty--compact"
                >
                  <strong>尚未选择成员</strong>
                  <p>从左侧列表勾选要移除的成员</p>
                </div>

                <div v-else class="create-group-modal__selected-list">
                  <button
                    v-for="member in selectedMembers"
                    :key="member.id"
                    type="button"
                    class="create-group-modal__member-chip"
                    :disabled="props.isSubmitting"
                    @click="removeMember(member.id)"
                  >
                    <span class="create-group-modal__member-avatar">
                      <img
                        v-if="member.avatarUrl"
                        :src="member.avatarUrl"
                        :alt="member.displayName"
                      />
                      <span v-else>{{
                        buildAvatarFallback(member.displayName)
                      }}</span>
                    </span>
                    <span>{{ member.displayName }}</span>
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
              :disabled="props.isSubmitting"
            >
              {{ props.isSubmitting ? "删除中..." : "删除成员" }}
            </button>
          </footer>
        </form>
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
.create-group-modal__member-chip {
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
.create-group-modal__empty strong {
  margin: 0;
  color: var(--text-primary);
}

.create-group-modal__header small,
.create-group-modal__picker-header small,
.create-group-modal__empty p,
.create-group-modal__friend-copy small {
  color: var(--text-secondary);
}

.create-group-modal__close,
.create-group-modal__secondary,
.create-group-modal__primary,
.create-group-modal__member-chip,
.create-group-modal__friend {
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

.create-group-modal__content {
  display: grid;
  gap: 18px;
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
  min-height: 360px;
  padding: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.76);
}

.create-group-modal__list {
  align-content: start;
  overflow: auto;
}

.create-group-modal__selected {
  align-content: start;
}

.create-group-modal__empty {
  display: grid;
  gap: 6px;
  place-items: center;
  min-height: 220px;
  text-align: center;
}

.create-group-modal__empty--compact {
  min-height: 140px;
}

.create-group-modal__friend {
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(241, 245, 249, 0.82);
  text-align: left;
}

.create-group-modal__friend:hover,
.create-group-modal__member-chip:hover,
.create-group-modal__close:hover,
.create-group-modal__secondary:hover,
.create-group-modal__primary:hover {
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

.create-group-modal__friend-copy {
  display: grid;
  gap: 4px;
  flex: 1;
  min-width: 0;
}

.create-group-modal__friend-copy strong,
.create-group-modal__friend-copy small,
.create-group-modal__friend-check {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.create-group-modal__friend-check {
  color: var(--primary-color-strong);
  font-size: 13px;
  font-weight: 700;
}

.create-group-modal__selected-list {
  display: grid;
  gap: 10px;
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
.create-group-modal__member-chip:disabled {
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
    min-height: 240px;
  }
}

@media (max-width: 640px) {
  .create-group-modal__header,
  .create-group-modal__footer {
    flex-direction: column;
    align-items: stretch;
  }

  .create-group-modal__close,
  .create-group-modal__secondary,
  .create-group-modal__primary {
    width: 100%;
    justify-content: center;
  }
}
</style>
