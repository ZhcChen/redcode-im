<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface TransferGroupOwnerCandidate {
  id: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
}

const props = defineProps<{
  visible: boolean;
  members: TransferGroupOwnerCandidate[];
  isLoading: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "submit", payload: { newOwnerId: string; displayName: string }): void;
}>();

const searchQuery = ref("");
const selectedMemberId = ref<string | null>(null);
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

const selectedMember = computed(
  () =>
    props.members.find((member) => member.id === selectedMemberId.value) ?? null,
);

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const resetForm = () => {
  searchQuery.value = "";
  selectedMemberId.value = null;
  validationMessage.value = null;
};

const close = () => {
  if (props.isSubmitting) {
    return;
  }
  emit("update:visible", false);
};

const selectMember = (memberId: string) => {
  selectedMemberId.value = memberId;
  validationMessage.value = null;
};

const handleSubmit = () => {
  if (!selectedMember.value) {
    validationMessage.value = "请选择新的群主";
    return;
  }

  validationMessage.value = null;
  emit("submit", {
    newOwnerId: selectedMember.value.id,
    displayName: selectedMember.value.displayName,
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
      <section class="create-group-modal__panel transfer-owner-modal__panel">
        <header class="create-group-modal__header">
          <div>
            <p class="create-group-modal__eyebrow">群聊</p>
            <h2>转让群主</h2>
            <small>转让后当前账号会失去群主权限，请谨慎操作。</small>
          </div>
          <button
            type="button"
            class="create-group-modal__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <form class="create-group-modal__content" @submit.prevent="handleSubmit">
          <section class="create-group-modal__picker">
            <div class="create-group-modal__picker-header">
              <div>
                <strong>选择新的群主</strong>
                <small>已自动过滤当前群主</small>
              </div>
              <span
                >{{ selectedMember ? "已选择 1 人" : "尚未选择" }}</span
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
                  v-else-if="!filteredMembers.length"
                  class="create-group-modal__empty"
                >
                  <strong>{{
                    props.members.length ? "暂无匹配成员" : "暂无可转让成员"
                  }}</strong>
                  <p>
                    {{
                      props.members.length
                        ? "换个关键词试试"
                        : "当前群内没有可接任群主的成员"
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
                        selectedMemberId === member.id,
                    }"
                    :disabled="props.isSubmitting"
                    @click="selectMember(member.id)"
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
                      selectedMemberId === member.id ? "已选" : "选择"
                    }}</span>
                  </button>
                </template>
              </div>

              <aside class="create-group-modal__selected">
                <div class="create-group-modal__picker-header">
                  <div>
                    <strong>确认对象</strong>
                    <small>提交后立即生效</small>
                  </div>
                  <span>{{ selectedMember ? "1 人" : "0 人" }}</span>
                </div>

                <div
                  v-if="!selectedMember"
                  class="create-group-modal__empty create-group-modal__empty--compact"
                >
                  <strong>尚未选择成员</strong>
                  <p>从左侧列表选择新的群主</p>
                </div>

                <div v-else class="transfer-owner-modal__selected">
                  <span class="create-group-modal__friend-avatar">
                    <img
                      v-if="selectedMember.avatarUrl"
                      :src="selectedMember.avatarUrl"
                      :alt="selectedMember.displayName"
                    />
                    <span v-else>{{
                      buildAvatarFallback(selectedMember.displayName)
                    }}</span>
                  </span>
                  <div class="transfer-owner-modal__selected-copy">
                    <strong>{{ selectedMember.displayName }}</strong>
                    <small>{{
                      selectedMember.subtitle || "暂无更多信息"
                    }}</small>
                  </div>
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
              :disabled="
                props.isLoading || props.isSubmitting || !selectedMemberId
              "
            >
              {{ props.isSubmitting ? "转让中..." : "确认转让" }}
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

.transfer-owner-modal__panel {
  width: min(880px, 100%);
}

.create-group-modal__header,
.create-group-modal__picker-header,
.create-group-modal__footer,
.create-group-modal__friend,
.transfer-owner-modal__selected {
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
.transfer-owner-modal__selected-copy strong {
  margin: 0;
  color: var(--text-primary);
}

.create-group-modal__header small,
.create-group-modal__picker-header small,
.create-group-modal__empty p,
.create-group-modal__friend-copy small,
.transfer-owner-modal__selected-copy small {
  color: var(--text-secondary);
}

.create-group-modal__close,
.create-group-modal__secondary,
.create-group-modal__primary,
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

.create-group-modal__content,
.create-group-modal__picker {
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

.create-group-modal__picker-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(260px, 0.85fr);
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

.create-group-modal__empty {
  display: grid;
  place-items: center;
  gap: 8px;
  min-height: 220px;
  text-align: center;
}

.create-group-modal__empty--compact {
  min-height: 140px;
}

.create-group-modal__friend {
  width: 100%;
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(248, 250, 252, 0.95);
  border-color: rgba(15, 23, 42, 0.06);
  text-align: left;
}

.create-group-modal__friend:hover,
.create-group-modal__friend--active,
.create-group-modal__close:hover,
.create-group-modal__secondary:hover,
.create-group-modal__primary:hover {
  transform: translateY(-1px);
}

.create-group-modal__friend--active {
  border-color: rgba(0, 155, 143, 0.32);
  background: rgba(240, 253, 250, 0.96);
}

.create-group-modal__friend-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  overflow: hidden;
  background: rgba(0, 155, 143, 0.12);
  color: var(--primary-color-strong);
  font-weight: 600;
}

.create-group-modal__friend-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.create-group-modal__friend-copy,
.transfer-owner-modal__selected-copy {
  flex: 1;
  display: grid;
  gap: 4px;
}

.create-group-modal__friend-check {
  color: var(--text-secondary);
  font-size: 12px;
}

.transfer-owner-modal__selected {
  align-items: flex-start;
  padding: 16px;
  border-radius: 18px;
  background: rgba(240, 253, 250, 0.88);
  border: 1px solid rgba(0, 155, 143, 0.12);
}

.create-group-modal__error {
  margin: 0;
  color: #d14343;
  font-size: 13px;
}

@media (max-width: 860px) {
  .create-group-modal__panel {
    padding: 22px;
  }

  .create-group-modal__picker-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .create-group-modal {
    padding: 16px;
  }

  .create-group-modal__header,
  .create-group-modal__footer {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
