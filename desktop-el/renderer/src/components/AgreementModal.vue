<script setup lang="ts">
const props = defineProps<{
  visible: boolean;
  title: string;
  htmlContent: string;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
}>();

const close = () => emit("update:visible", false);
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="agreement-modal">
      <div class="agreement-modal__backdrop" @click="close" />
      <section class="agreement-modal__panel">
        <header class="agreement-modal__header">
          <div>
            <p class="agreement-modal__eyebrow">公开文档</p>
            <h2>{{ props.title }}</h2>
          </div>
          <button type="button" class="agreement-modal__close" @click="close">关闭</button>
        </header>
        <div class="agreement-modal__content" v-html="props.htmlContent" />
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.agreement-modal {
  position: fixed;
  inset: 0;
  z-index: 40;
  display: grid;
  place-items: center;
  padding: 24px;
}

.agreement-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.46);
  backdrop-filter: blur(8px);
}

.agreement-modal__panel {
  position: relative;
  z-index: 1;
  width: min(760px, 100%);
  max-height: min(80vh, 720px);
  overflow: auto;
  border-radius: 28px;
  background: #ffffff;
  box-shadow: 0 30px 80px rgba(15, 23, 42, 0.22);
  padding: 28px 28px 24px;
}

.agreement-modal__header {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
  margin-bottom: 20px;
}

.agreement-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.agreement-modal__header h2 {
  margin: 0;
  font-size: 24px;
}

.agreement-modal__close {
  height: 40px;
  padding: 0 16px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
  cursor: pointer;
}

.agreement-modal__content {
  color: var(--text-primary);
  line-height: 1.7;
  font-size: 14px;
}

.agreement-modal__content :deep(h1),
.agreement-modal__content :deep(h2),
.agreement-modal__content :deep(h3) {
  color: var(--text-primary);
  margin: 20px 0 12px;
}

.agreement-modal__content :deep(p) {
  margin: 0 0 12px;
}

.agreement-modal__content :deep(ul),
.agreement-modal__content :deep(ol) {
  margin: 0 0 12px;
  padding-left: 20px;
}

.agreement-modal__content :deep(a) {
  color: var(--primary-color-strong);
}
</style>
