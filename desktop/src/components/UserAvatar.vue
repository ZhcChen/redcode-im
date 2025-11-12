<template>
  <Avatar
    :src="computedAvatarSrc"
    :text="displayName"
    :alt="alt"
    :size="size"
    :circle="circle"
    :background-color="backgroundColor"
    :text-color="textColor"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import Avatar from './Avatar.vue'

interface Props {
  /** 远程头像 URL (avatarUrl) */
  avatarUrl?: string | null
  /** 本地缓存路径 (avatarLocalPath) - 优先使用 */
  avatarLocalPath?: string | null
  /** 用户显示名称 (用于生成文字头像) */
  displayName?: string
  /** 图片 alt 属性 */
  alt?: string
  /** 头像尺寸 */
  size?: number | string
  /** 是否为圆形 */
  circle?: boolean
  /** 背景颜色 */
  backgroundColor?: string
  /** 文字颜色 */
  textColor?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: 48,
  circle: true,
  alt: '头像'
})

/**
 * 计算最终显示的头像 URL
 * 优先级: 本地缓存路径 (avatarLocalPath) > 远程 URL (avatarUrl)
 *
 * 这个逻辑与 Settings.vue 中的 userAvatarLocalPath 保持一致
 */
const computedAvatarSrc = computed(() => {
  // 1. 优先使用本地缓存路径
  if (props.avatarLocalPath && props.avatarLocalPath.trim()) {
    return props.avatarLocalPath
  }

  // 2. 使用远程 URL
  if (props.avatarUrl && props.avatarUrl.trim()) {
    return props.avatarUrl
  }

  // 3. 没有可用的头像,返回 undefined 让 Avatar 组件显示文字或默认头像
  return undefined
})
</script>

