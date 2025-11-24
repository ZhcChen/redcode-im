<template>
  <div
    class="b-switch"
    :class="{ 'b-switch--checked': modelValue }"
    @click="handleToggle"
  >
    <div class="b-switch__circle"></div>
  </div>
</template>

<script setup lang="ts">
interface Props {
  modelValue: boolean
  disabled?: boolean
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void
  (e: 'change', value: boolean): void
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false
})

const emit = defineEmits<Emits>()

const handleToggle = () => {
  if (props.disabled) return

  const newValue = !props.modelValue
  emit('update:modelValue', newValue)
  emit('change', newValue)
}
</script>

<style lang="scss" scoped>
.b-switch {
  position: relative;
  display: inline-block;
  width: 50px;
  height: 22px;
  background-color: #D0D1DB; /* 关闭时的背景色 */
  border-radius: 11px;
  transition: background-color 0.3s ease;

  &--checked {
    background-color: var(--primary-color, #4ECDC4); /* 开启时使用主色调 */
  }

  &__circle {
    position: absolute;
    top: 4px; /* 上下居中：(22px - 14px) / 2 = 4px */
    left: 4px; /* 关闭时在左边，距离左边4px */
    width: 14px;
    height: 14px;
    background-color: white;
    border-radius: 50%;
    transition: transform 0.3s ease;
    transform: translateX(0); /* 关闭时的位置 */
  }

  &--checked &__circle {
    transform: translateX(28px); /* 开启时的位置：50px - 14px - 4px - 4px = 28px */
  }

  &:hover:not([disabled]) {
    opacity: 0.8;
  }

  &[disabled] {
    opacity: 0.5;
    cursor: not-allowed;
  }
}
</style>