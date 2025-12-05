<template>
  <div v-if="message" class="pinned-message-banner">
    <div class="pinned-indicators">
      <span
        v-for="(_, index) in indicators"
        :key="index"
        :class="['pinned-indicator', { 'pinned-indicator--active': index === props.activeIndex }]"
      />
    </div>
    <div class="pinned-main" @click="handleClick">
      <Transition name="pinned-banner-slide" mode="out-in">
        <div class="pinned-main-inner" :key="previewKey">
          <div class="pinned-header">
            <span class="pinned-title">置顶消息</span>
            <span v-if="total > 1" class="pinned-count">{{ total }} 条</span>
          </div>
          <div class="pinned-preview">{{ previewText }}</div>
        </div>
      </Transition>
    </div>
    <button
      class="pinned-icon-button"
      type="button"
      @click.stop="handleIconClick"
      title="查看置顶消息"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 17v5M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>
      </svg>
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Message } from '@/types/models'

// 内容类型常量
const CONTENT_TYPE = {
  TEXT: 1,
  IMAGE: 2,
  VIDEO: 3,
  AUDIO: 4,
  FILE: 5,
  MIXED: 14
}

interface Props {
  message: Message | null
  /** 置顶消息数量，用于显示指标条，默认 1 条 */
  total?: number
  /** 当前激活的置顶消息索引（从 0 开始） */
  activeIndex?: number
}

interface Emits {
  // 点击主体区域：滚动到当前/上一条置顶消息
  (e: 'click'): void
  // 点击右侧图标：打开置顶消息抽屉
  (e: 'icon-click'): void
}

const props = withDefaults(defineProps<Props>(), {
  total: 1,
  activeIndex: 0
})
const emit = defineEmits<Emits>()

const indicators = computed(() => {
  const count = Math.max(props.total || 1, 1)
  return Array.from({ length: count })
})

const previewText = computed(() => {
  if (!props.message) return ''

  if (props.message.isDeleted) {
    return '消息已删除'
  }

  const contentType = props.message.contentType

  // 检查是否有 parts
  if (props.message.parts && props.message.parts.length > 0) {
    const parts = props.message.parts
    const hasImage = parts.some(p => p.type === 'image')
    const hasVideo = parts.some(p => p.type === 'video')
    const hasAudio = parts.some(p => p.type === 'audio')
    const hasFile = parts.some(p => p.type === 'file')
    const textPart = parts.find(p => p.type === 'text')

    if (textPart?.content) {
      return textPart.content
    }
    if (hasImage && hasVideo) return '[多媒体消息]'
    if (hasImage) return '[图片消息]'
    if (hasVideo) return '[视频消息]'
    if (hasAudio) return '[语音消息]'
    if (hasFile) return '[文件消息]'
  }

  switch (contentType) {
    case CONTENT_TYPE.TEXT:
      return props.message.content || ''
    case CONTENT_TYPE.IMAGE:
      return '[图片消息]'
    case CONTENT_TYPE.AUDIO:
      return '[语音消息]'
    case CONTENT_TYPE.VIDEO:
      return '[视频消息]'
    case CONTENT_TYPE.FILE:
      return '[文件消息]'
    case CONTENT_TYPE.MIXED:
      return '[多媒体消息]'
    default:
      return props.message.content || '[消息]'
  }
})

const previewKey = computed(() => {
  return props.message?.id || 'empty'
})

const handleClick = () => {
  emit('click')
}

const handleIconClick = () => {
  emit('icon-click')
}
</script>

<style scoped lang="scss">
.pinned-message-banner {
  display: flex;
  align-items: stretch;
  width: 100%;
  background: #ffffff;
  border-top: 1px solid #f0f0f0;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;
  height: 52px; /* 固定高度，避免轮播切换时整体高度抖动 */
  box-sizing: border-box;
}

.pinned-indicators {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
  padding: 10px 0 10px 16px;
}

.pinned-indicator {
  width: 2px;
  height: 14px;
  border-radius: 999px;
  background-color: rgba(var(--primary-rgb, 0, 194, 179), 0.25);
}

.pinned-indicator--active {
  background-color: var(--primary-color, #00C2B3);
}

.pinned-main {
  flex: 1;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  cursor: pointer;
  min-width: 0; // 允许内部文本收缩，配合省略号
  overflow: hidden; // 为上下滚动动画提供裁剪容器
}

.pinned-main-inner {
  display: flex;
  flex-direction: column;
}

.pinned-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 2px;
}

.pinned-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--primary-color, #00C2B3);
}

.pinned-count {
  font-size: 12px;
  color: #999999;
}

.pinned-preview {
  font-size: 13px;
  color: #666666;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.pinned-icon-button {
  min-width: 64px;
  border: none;
  background: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 0 16px 0 12px; // 右侧间距缩小，让图标更靠近右边缘，视觉上与顶部群设置按钮更对齐
}

.pinned-icon-button svg {
  stroke: #555555;
  width: 22px;
  height: 22px;
}

.pinned-icon-button:hover svg {
  stroke: #222222;
}

/* 置顶 Banner 文本上下滚动动画 */
.pinned-banner-slide-enter-active,
.pinned-banner-slide-leave-active {
  transition: transform 0.32s cubic-bezier(0.22, 0.61, 0.36, 1), opacity 0.28s ease-out;
  will-change: transform, opacity;
}

.pinned-banner-slide-enter-from {
  transform: translateY(100%);
  opacity: 0;
}

.pinned-banner-slide-enter-to {
  transform: translateY(0);
  opacity: 1;
}

.pinned-banner-slide-leave-from {
  transform: translateY(0);
  opacity: 1;
}

.pinned-banner-slide-leave-to {
  transform: translateY(-100%);
  opacity: 0;
}
</style>
