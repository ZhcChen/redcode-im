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
  /** 显示的文字（当没有图片时） */
  text?: string
  /** 背景颜色 */
  backgroundColor?: string
  /** 文字颜色 */
  textColor?: string
  /** 默认头像图片地址，当没有src和text时显示 */
  defaultSrc?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: 48,
  circle: true,
  alt: '头像',
  backgroundColor: '#f0f0f0',
  textColor: '#666',
  defaultSrc: defaultAvatarSvg
})

const imageError = ref(false)

// 当 src 变化时,重置错误状态
watch(() => props.src, (newSrc, oldSrc) => {
  if (newSrc !== oldSrc) {
    console.log('[Avatar] 📸 src 属性变化,重置 imageError', { oldSrc, newSrc })
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

// 头像样式
const avatarStyle = computed(() => ({
  width: sizeValue.value,
  height: sizeValue.value,
  backgroundColor: props.backgroundColor
}))

// 文字样式
const textStyle = computed(() => {
  const fontSize = typeof props.size === 'number' 
    ? `${Math.floor(props.size * 0.4)}px` 
    : '19px'
  
  return {
    fontSize,
    color: props.textColor
  }
})

// 显示的文字（取前两个字符）
const displayText = computed(() => {
  if (!props.text) return ''
  return props.text.slice(0, 2)
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
