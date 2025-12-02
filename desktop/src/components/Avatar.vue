<template>
  <div 
    class="bear-avatar"
    :class="{
      'bear-avatar--circle': circle,
      'bear-avatar--square': !circle
    }"
    :style="avatarStyle"
  >
    <img 
      v-if="src && !imageError"
      :src="src" 
      :alt="alt"
      class="bear-avatar__image"
      @error="handleImageError"
      @load="handleImageLoad"
    />
    <div 
      v-else-if="text" 
      class="bear-avatar__text"
      :style="textStyle"
    >
      {{ displayText }}
    </div>
    <div 
      v-else 
      class="bear-avatar__default"
    >
      <img 
        :src="props.defaultSrc" 
        alt="默认头像" 
        class="bear-avatar__default-image"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import defaultAvatarSvg from '../assets/image/default-avatar.svg'

interface Props {
  /** 头像图片地址 */
  src?: string
  /** 图片alt属性 */
  alt?: string
  /** 头像尺寸，可以是数字（px）或字符串 */
  size?: number | string
  /** 是否为圆形，默认true */
  circle?: boolean
  /** 显示的文字（当没有图片时），自动取首字 */
  text?: string
  /** 背景颜色（如果不指定，会根据text自动生成） */
  backgroundColor?: string
  /** 文字颜色 */
  textColor?: string
  /** 默认头像图片地址，当没有src和text时显示 */
  defaultSrc?: string
  /** 背景色计算用的种子，默认使用 text */
  colorSeed?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: 48,
  circle: true,
  alt: '头像',
  textColor: '#ffffff',
  defaultSrc: defaultAvatarSvg
})

const imageError = ref(false)

// 当 src 变化时,重置错误状态
watch(() => props.src, (newSrc, oldSrc) => {
  if (newSrc !== oldSrc) {
    imageError.value = false
  }
})

// 处理尺寸
const sizeValue = computed(() => {
  if (typeof props.size === 'number') {
    return `${props.size}px`
  }
  return props.size
})

// 字符串哈希函数（用于生成一致的颜色）
const hashCode = (str: string): number => {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash // Convert to 32bit integer
  }
  return Math.abs(hash)
}

// 根据文本生成背景颜色
const generateBackgroundColor = (text: string): string => {
  if (!text) return '#6366f1'
  
  // 预设的柔和色调
  const colors = [
    '#6366f1', // 靛蓝
    '#8b5cf6', // 紫色
    '#ec4899', // 粉红
    '#f43f5e', // 玫瑰
    '#f59e0b', // 琥珀
    '#10b981', // 翠绿
    '#06b6d4', // 青色
    '#3b82f6', // 蓝色
    '#6366f1', // 靛蓝
    '#a855f7', // 紫罗兰
  ]
  
  const hash = hashCode(text)
  return colors[hash % colors.length]
}

const seedText = computed(() => props.colorSeed || props.text || '')

// 计算背景颜色
const computedBackgroundColor = computed(() => {
  // 如果指定了背景色，使用指定的
  if (props.backgroundColor) {
    return props.backgroundColor
  }
  
  // 如果有文字，基于文字生成颜色
  if (seedText.value) {
    return generateBackgroundColor(seedText.value)
  }
  
  // 默认颜色
  return '#f0f0f0'
})

// 头像样式
const avatarStyle = computed(() => ({
  width: sizeValue.value,
  height: sizeValue.value,
  backgroundColor: computedBackgroundColor.value
}))

// 文字样式
const textStyle = computed(() => {
  const fontSize = typeof props.size === 'number' 
    ? `${Math.floor(props.size * 0.45)}px` 
    : '22px'
  
  return {
    fontSize,
    color: props.textColor,
    fontWeight: '500'
  }
})

// 显示的文字（只取首字）
const displayText = computed(() => {
  if (!props.text) return ''
  
  // 去除空格后取第一个字符
  const trimmed = props.text.trim()
  if (!trimmed) return ''
  
  // 只取首字符
  const firstChar = trimmed.charAt(0)
  
  // 如果是英文，转大写
  if (/^[a-zA-Z]$/.test(firstChar)) {
    return firstChar.toUpperCase()
  }
  
  // 其他字符（中文等）直接返回
  return firstChar
})

// 处理图片加载错误
const handleImageError = () => {
  imageError.value = true
}

// 处理图片加载成功
const handleImageLoad = () => {
  imageError.value = false
}
</script>

<style lang="scss" scoped>
.bear-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  background-color: #f0f0f0;
  flex-shrink: 0;
  
  &--circle {
    border-radius: 50%;
  }
  
  &--square {
    border-radius: 4px;
  }
  
  &__image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  
  &__text {
    font-weight: 500;
    line-height: 1;
    user-select: none;
    text-align: center;
    cursor: default;
  }
  
  &__default {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    
    &-image {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }
  }
}
</style>
