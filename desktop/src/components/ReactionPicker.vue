<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="reaction-picker"
      :style="pickerStyle"
      @click.stop
    >
      <div
        v-for="reaction in reactions"
        :key="reaction"
        class="reaction-item"
        @click="handleSelect(reaction)"
      >
        {{ reaction }}
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'

interface Props {
  visible: boolean
  position: { x: number; y: number }
  reactions?: string[]
}

interface Emits {
  (e: 'select', reaction: string): void
  (e: 'update:visible', value: boolean): void
}

const props = withDefaults(defineProps<Props>(), {
  reactions: () => ['👍', '❤️', '😂', '🎉', '😮', '😢'],
})

const emit = defineEmits<Emits>()

const pickerStyle = computed(() => {
  const pickerWidth = 240
  const pickerHeight = 60
  const padding = 8

  let x = props.position.x
  let y = props.position.y - pickerHeight - 10 // 显示在鼠标上方

  // 检查右侧是否超出
  if (x + pickerWidth + padding > window.innerWidth) {
    x = window.innerWidth - pickerWidth - padding
  }

  // 检查左侧是否超出
  if (x < padding) {
    x = padding
  }

  // 检查顶部是否超出
  if (y < padding) {
    y = props.position.y + 30 // 显示在鼠标下方
  }

  return {
    left: `${x}px`,
    top: `${y}px`,
  }
})

const handleSelect = (reaction: string) => {
  emit('select', reaction)
  emit('update:visible', false)
}

// 点击外部关闭
const handleClickOutside = (event: MouseEvent) => {
  if (props.visible) {
    const target = event.target as HTMLElement
    if (!target.closest('.reaction-picker')) {
      emit('update:visible', false)
    }
  }
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      setTimeout(() => document.addEventListener('click', handleClickOutside), 0)
    } else {
      document.removeEventListener('click', handleClickOutside)
    }
  },
)
</script>

<style scoped lang="scss">
.reaction-picker {
  position: fixed;
  z-index: 10001;
  background: rgba(255, 255, 255, 0.98);
  border-radius: 24px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12), 0 2px 8px rgba(0, 0, 0, 0.08);
  padding: 8px;
  display: flex;
  gap: 8px;
  user-select: none;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(0, 0, 0, 0.06);
  animation: pickerFadeIn 0.15s ease-out;

  .reaction-item {
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    cursor: pointer;
    border-radius: 50%;
    transition: all 0.15s;

    &:hover {
      background-color: rgba(0, 0, 0, 0.06);
      transform: scale(1.2);
    }

    &:active {
      transform: scale(1.1);
    }
  }
}

@keyframes pickerFadeIn {
  from {
    opacity: 0;
    transform: scale(0.9) translateY(10px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}
</style>

