<script setup lang="ts">
import { computed, ref, watch } from "vue";

interface GroupRuleEntry {
  id: string;
  title: string;
  content: string;
  orderIndex: number;
  creatorLabel: string | null;
  updatedAtLabel: string | null;
}

const props = defineProps<{
  visible: boolean;
  rules: GroupRuleEntry[];
  canManage: boolean;
  isLoading: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "create", payload: {
    title: string;
    content: string;
    orderIndex: number;
  }): void;
  (event: "update", payload: {
    ruleId: string;
    title: string;
    content: string;
  }): void;
  (event: "delete", payload: { ruleId: string; title: string }): void;
}>();

const editingRuleId = ref<string | null>(null);
const title = ref("");
const content = ref("");
const validationMessage = ref<string | null>(null);

const editingRule = computed(
  () =>
    props.rules.find((rule) => rule.id === editingRuleId.value) ?? null,
);

const isEditing = computed(() => Boolean(editingRuleId.value));

const resetForm = () => {
  editingRuleId.value = null;
  title.value = "";
  content.value = "";
  validationMessage.value = null;
};

const close = () => {
  if (props.isSubmitting) {
    return;
  }
  emit("update:visible", false);
};

const startCreate = () => {
  resetForm();
};

const startEdit = (rule: GroupRuleEntry) => {
  editingRuleId.value = rule.id;
  title.value = rule.title;
  content.value = rule.content;
  validationMessage.value = null;
};

const cancelEdit = () => {
  resetForm();
};

const handleSave = () => {
  const trimmedTitle = title.value.trim();
  const trimmedContent = content.value.trim();

  if (!trimmedTitle) {
    validationMessage.value = "请输入群规标题";
    return;
  }
  if (!trimmedContent) {
    validationMessage.value = "请输入群规内容";
    return;
  }

  validationMessage.value = null;
  if (editingRuleId.value) {
    emit("update", {
      ruleId: editingRuleId.value,
      title: trimmedTitle,
      content: trimmedContent,
    });
    return;
  }

  emit("create", {
    title: trimmedTitle,
    content: trimmedContent,
    orderIndex: props.rules.length,
  });
};

const handleDelete = (rule: GroupRuleEntry) => {
  if (props.isSubmitting) {
    return;
  }

  emit("delete", {
    ruleId: rule.id,
    title: rule.title,
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
    <div v-if="props.visible" class="manage-group-rules">
      <div class="manage-group-rules__backdrop" @click="close" />
      <section class="manage-group-rules__panel">
        <header class="manage-group-rules__header">
          <div>
            <p class="manage-group-rules__eyebrow">群聊</p>
            <h2>群规</h2>
            <small>{{
              props.canManage
                ? "群成员可查看群规，群主或管理员可新增、编辑和删除。"
                : "当前群成员都可以查看这里的群规。"
            }}</small>
          </div>
          <button
            type="button"
            class="manage-group-rules__close"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="manage-group-rules__stack">
          <section class="manage-group-rules__list-section">
            <div class="manage-group-rules__section-head">
              <div>
                <strong>当前群规</strong>
                <small>按序号升序展示有效群规</small>
              </div>
              <span>{{ props.rules.length }} 条</span>
            </div>

            <div v-if="props.isLoading" class="manage-group-rules__empty">
              <strong>加载中</strong>
              <p>正在同步群规列表...</p>
            </div>

            <div
              v-else-if="!props.rules.length"
              class="manage-group-rules__empty manage-group-rules__empty--compact"
            >
              <strong>暂无群规</strong>
              <p>{{
                props.canManage
                  ? "当前群还没有群规，可以在下方直接新增。"
                  : "当前群暂未设置群规。"
              }}</p>
            </div>

            <div v-else class="manage-group-rules__list">
              <article
                v-for="rule in props.rules"
                :key="rule.id"
                class="manage-group-rules__item"
              >
                <div class="manage-group-rules__item-head">
                  <div class="manage-group-rules__title-row">
                    <span class="manage-group-rules__index">{{
                      rule.orderIndex + 1
                    }}</span>
                    <strong>{{ rule.title }}</strong>
                  </div>
                  <div
                    v-if="props.canManage"
                    class="manage-group-rules__item-actions"
                  >
                    <button
                      type="button"
                      class="manage-group-rules__ghost"
                      :disabled="props.isSubmitting"
                      @click="startEdit(rule)"
                    >
                      编辑
                    </button>
                    <button
                      type="button"
                      class="manage-group-rules__danger"
                      :disabled="props.isSubmitting"
                      @click="handleDelete(rule)"
                    >
                      删除
                    </button>
                  </div>
                </div>
                <p class="manage-group-rules__content">{{ rule.content }}</p>
                <div class="manage-group-rules__meta">
                  <small v-if="rule.creatorLabel">创建人：{{ rule.creatorLabel }}</small>
                  <small v-if="rule.updatedAtLabel">
                    更新时间：{{ rule.updatedAtLabel }}
                  </small>
                </div>
              </article>
            </div>
          </section>

          <form
            v-if="props.canManage"
            class="manage-group-rules__editor"
            @submit.prevent="handleSave"
          >
            <div class="manage-group-rules__section-head">
              <div>
                <strong>{{ isEditing ? "编辑群规" : "新增群规" }}</strong>
                <small>{{
                  isEditing
                    ? "修改标题或内容后保存即可生效"
                    : "标题和内容都是必填项"
                }}</small>
              </div>
              <div class="manage-group-rules__editor-actions">
                <button
                  v-if="isEditing"
                  type="button"
                  class="manage-group-rules__ghost"
                  :disabled="props.isSubmitting"
                  @click="cancelEdit"
                >
                  取消
                </button>
                <button
                  v-else
                  type="button"
                  class="manage-group-rules__ghost"
                  :disabled="props.isSubmitting"
                  @click="startCreate"
                >
                  清空
                </button>
              </div>
            </div>

            <label class="manage-group-rules__field">
              <span>标题</span>
              <input
                v-model="title"
                type="text"
                maxlength="50"
                placeholder="请输入群规标题"
                :disabled="props.isSubmitting"
              />
            </label>

            <label class="manage-group-rules__field">
              <span>内容</span>
              <textarea
                v-model="content"
                rows="6"
                maxlength="500"
                placeholder="请输入群规内容"
                :disabled="props.isSubmitting"
              />
            </label>

            <p v-if="validationMessage" class="manage-group-rules__validation">
              {{ validationMessage }}
            </p>

            <div class="manage-group-rules__footer">
              <small>
                {{
                  isEditing && editingRule
                    ? `正在编辑第 ${editingRule.orderIndex + 1} 条群规`
                    : `新增后将排在第 ${props.rules.length + 1} 条`
                }}
              </small>
              <button
                type="submit"
                class="manage-group-rules__submit"
                :disabled="props.isLoading || props.isSubmitting"
              >
                {{
                  props.isSubmitting
                    ? "提交中..."
                    : isEditing
                      ? "保存修改"
                      : "新增群规"
                }}
              </button>
            </div>
          </form>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.manage-group-rules {
  position: fixed;
  inset: 0;
  z-index: 52;
  display: grid;
  place-items: center;
  padding: 24px;
}

.manage-group-rules__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.manage-group-rules__panel {
  position: relative;
  z-index: 1;
  width: min(920px, 100%);
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

.manage-group-rules__header,
.manage-group-rules__section-head,
.manage-group-rules__item-head,
.manage-group-rules__footer,
.manage-group-rules__editor-actions,
.manage-group-rules__item-actions {
  display: flex;
  gap: 12px;
}

.manage-group-rules__header,
.manage-group-rules__section-head,
.manage-group-rules__footer {
  align-items: center;
  justify-content: space-between;
}

.manage-group-rules__header {
  align-items: flex-start;
  margin-bottom: 20px;
}

.manage-group-rules__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.manage-group-rules__header h2,
.manage-group-rules__section-head strong,
.manage-group-rules__empty strong,
.manage-group-rules__item strong {
  margin: 0;
  color: var(--text-primary);
}

.manage-group-rules__header small,
.manage-group-rules__section-head small,
.manage-group-rules__empty p,
.manage-group-rules__meta small,
.manage-group-rules__footer small {
  color: var(--text-secondary);
}

.manage-group-rules__close,
.manage-group-rules__ghost,
.manage-group-rules__danger,
.manage-group-rules__submit {
  border: 1px solid transparent;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.manage-group-rules__close,
.manage-group-rules__ghost {
  height: 40px;
  padding: 0 16px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.manage-group-rules__danger {
  height: 40px;
  padding: 0 16px;
  border-radius: 999px;
  background: rgba(239, 68, 68, 0.12);
  color: #b91c1c;
}

.manage-group-rules__submit {
  height: 44px;
  padding: 0 18px;
  border-radius: 999px;
  background: linear-gradient(135deg, #0f766e, #0ea5e9);
  color: #ffffff;
}

.manage-group-rules__close:hover,
.manage-group-rules__ghost:hover,
.manage-group-rules__danger:hover,
.manage-group-rules__submit:hover {
  transform: translateY(-1px);
}

.manage-group-rules__stack,
.manage-group-rules__list-section,
.manage-group-rules__editor {
  display: grid;
  gap: 14px;
}

.manage-group-rules__list-section,
.manage-group-rules__editor {
  padding: 18px;
  border-radius: 22px;
  background: rgba(248, 250, 252, 0.86);
  border: 1px solid rgba(148, 163, 184, 0.18);
}

.manage-group-rules__empty {
  display: grid;
  place-items: center;
  min-height: 180px;
  border-radius: 18px;
  background: rgba(241, 245, 249, 0.86);
  text-align: center;
}

.manage-group-rules__empty--compact {
  min-height: 120px;
}

.manage-group-rules__list {
  display: grid;
  gap: 12px;
}

.manage-group-rules__item {
  display: grid;
  gap: 10px;
  padding: 16px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.92);
}

.manage-group-rules__item-head {
  justify-content: space-between;
  align-items: flex-start;
}

.manage-group-rules__title-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.manage-group-rules__index {
  display: inline-grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 999px;
  background: rgba(14, 116, 144, 0.12);
  color: #0f766e;
  font-size: 12px;
  font-weight: 700;
}

.manage-group-rules__content {
  margin: 0;
  color: var(--text-primary);
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.manage-group-rules__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.manage-group-rules__field {
  display: grid;
  gap: 8px;
}

.manage-group-rules__field span {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
}

.manage-group-rules__field input,
.manage-group-rules__field textarea {
  width: 100%;
  border: 1px solid rgba(148, 163, 184, 0.24);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.94);
  color: var(--text-primary);
  outline: none;
}

.manage-group-rules__field input {
  min-height: 46px;
  padding: 0 14px;
}

.manage-group-rules__field textarea {
  padding: 12px 14px;
  resize: vertical;
}

.manage-group-rules__validation {
  margin: 0;
  color: #b91c1c;
  font-size: 13px;
}

@media (max-width: 900px) {
  .manage-group-rules {
    padding: 16px;
  }

  .manage-group-rules__panel {
    padding: 20px;
  }

  .manage-group-rules__item-head,
  .manage-group-rules__footer,
  .manage-group-rules__section-head,
  .manage-group-rules__header {
    flex-direction: column;
    align-items: stretch;
  }

  .manage-group-rules__item-actions,
  .manage-group-rules__editor-actions {
    justify-content: flex-start;
  }
}
</style>
