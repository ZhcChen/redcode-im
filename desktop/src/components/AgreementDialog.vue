<template>
  <Dialog
    v-model="isVisible"
    :title="title"
    :closeOnOverlay="true"
    :showFooter="false"
  >
    <div class="agreement-dialog-content" v-html="htmlContent"></div>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import Dialog from './Dialog.vue'

interface Props {
  visible: boolean
  title: string
  htmlContent: string
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'close'): void
}>()

const isVisible = ref(props.visible)

watch(() => props.visible, (newValue) => {
  isVisible.value = newValue
})

watch(isVisible, (newValue) => {
  emit('update:visible', newValue)
  if (!newValue) {
    emit('close')
  }
})
</script>

<style scoped lang="scss">
.agreement-dialog-content {
  max-height: 60vh;
  overflow-y: auto;
  padding: 8px 0;
  color: var(--text-primary);
  line-height: 1.6;
  font-size: 14px;

  :deep(h1),
  :deep(h2),
  :deep(h3) {
    color: var(--text-primary);
    margin-top: 20px;
    margin-bottom: 12px;
    font-weight: 600;
  }

  :deep(h1) {
    font-size: 20px;
  }

  :deep(h2) {
    font-size: 18px;
    border-bottom: 1px solid var(--divider);
    padding-bottom: 8px;
  }

  :deep(h3) {
    font-size: 16px;
  }

  :deep(p) {
    margin-bottom: 12px;
  }

  :deep(ul),
  :deep(ol) {
    padding-left: 20px;
    margin-bottom: 12px;
  }

  :deep(li) {
    margin-bottom: 4px;
  }

  :deep(a) {
    color: var(--primary-color);
    text-decoration: underline;
  }
}
</style>

