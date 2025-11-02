<template>
  <div class="badge" :class="badgeClass">
    {{ displayValue }}
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  value?: number | string
  max?: number
  color?: string
  size?: 'small' | 'default' | 'large'
}

const props = withDefaults(defineProps<Props>(), {
  value: 0,
  max: 99,
  color: 'primary',
  size: 'default'
})

// 计算显示的值
const displayValue = computed(() => {
  const numValue = Number(props.value)
  if (isNaN(numValue) || numValue <= 0) {
    return ''
  }
  return numValue > props.max ? `${props.max}+` : String(numValue)
})

// 计算样式类
const badgeClass = computed(() => [
  `badge--${props.color}`,
  `badge--${props.size}`,
  {
    'badge--hidden': !displayValue.value
  }
])
</script>

<style lang="scss" scoped>

.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 6px;
  font-size: $font-size-xs; // 12px
  font-weight: $font-weight-medium;
  color: $text-white;
  background-color: $primary-color;
  border-radius: 9px;
  line-height: 1;
  white-space: nowrap;
  text-align: center;
  box-sizing: border-box;
  transition: all $transition-fast;
  
  // 确保单个数字时保持圆形
  &:not(:has(+ *)) {
    min-width: 18px;
  }

  // 隐藏状态
  &--hidden {
    display: none;
  }

  // 颜色变体
  &--primary {
    background-color: $primary-color;
  }

  &--secondary {
    background-color: $secondary-color;
  }

  &--success {
    background-color: $success-color;
  }

  &--warning {
    background-color: $warning-color;
  }

  &--error {
    background-color: $error-color;
  }

  &--info {
    background-color: $info-color;
  }

  // 尺寸变体
  &--small {
    min-width: 16px;
    height: 16px;
    padding: 0 4px;
    font-size: 10px;
    border-radius: 8px;
  }

  &--default {
    min-width: 18px;
    height: 18px;
    padding: 0 6px;
    font-size: $font-size-xs; // 12px
    border-radius: 9px;
  }

  &--large {
    min-width: 20px;
    height: 20px;
    padding: 0 8px;
    font-size: $font-size-sm; // 14px
    border-radius: 10px;
  }

  // 空内容时的特殊处理
  &:empty {
    display: none;
  }
}
</style>
