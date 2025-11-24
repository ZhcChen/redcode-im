<template>
  <button
    class="toolbar-btn"
    :class="buttonClass"
    :disabled="disabled"
    @click="handleClick"
  >
    <slot />
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  disabled?: boolean
  variant?: 'default' | 'primary' | 'ghost' | 'back'
}

interface Emits {
  click: []
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  variant: 'default'
})

const emit = defineEmits<Emits>()

const buttonClass = computed(() => {
  return `toolbar-btn-${props.variant}`
})

const handleClick = () => {
  if (!props.disabled) {
    emit('click')
  }
}
</script>

<style lang="scss" scoped>
.toolbar-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border: none;
  background: transparent;
  color: #374151;
  border-radius: 8px;
  transition: background-color 0.2s;
  font-size: 14px;
  font-weight: 500;

  &:hover:not(:disabled) {
    background-color: #f3f4f6;
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  img {
    width: 20px;
    height: 20px;
  }
}

// 变体样式（如果需要的话）
.toolbar-btn-primary {
  background: #2563eb;
  color: #fff;

  &:hover:not(:disabled) {
    background: #1d4ed8;
  }
}

.toolbar-btn-ghost {
  border: 1px solid #e2e8f0;
  color: #1d4ed8;
}

.toolbar-btn-back {
  // 特殊样式可以在这里定义
}
</style>
