<template>
  <div v-if="message" class="pinned-message-banner" @click="handleClick">
    <div class="pin-icon">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 17v5M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>
      </svg>
    </div>
    <div class="pin-content">
      <div class="pin-label">已置顶</div>
      <div class="pin-preview">{{ previewText }}</div>
    </div>
    <button class="pin-close" @click.stop="handleUnpin" title="取消置顶">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <line x1="18" y1="6" x2="6" y2="18"/>
        <line x1="6" y1="6" x2="18" y2="18"/>
      </svg>
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Message } from '@/types/models'
import { MESSAGE_CONSTANTS } from '@/constants/message'

interface Props {
  message: Message | null
}

interface Emits {
  (e: 'click'): void
  (e: 'unpin'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

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
    case MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE:
      return props.message.content || ''
    case MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE:
      return '[图片消息]'
    case MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE:
      return '[语音消息]'
    case MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE:
      return '[视频消息]'
    case MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE:
      return '[文件消息]'
    case MESSAGE_CONSTANTS.CONTENT_TYPE.MIXED_CONTENT_TYPE:
      return '[多媒体消息]'
    default:
      return props.message.content || '[消息]'
  }
})

const handleClick = () => {
  emit('click')
}

const handleUnpin = () => {
  emit('unpin')
}
</script>

<style scoped lang="scss">
.pinned-message-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  margin: 0 16px 8px 16px;
  background: rgba(var(--primary-rgb, 64, 158, 255), 0.08);
  border-radius: 12px;
  border: 1px solid rgba(var(--primary-rgb, 64, 158, 255), 0.15);
  cursor: pointer;
  transition: all 0.2s ease;
  flex-shrink: 0;

  &:hover {
    background: rgba(var(--primary-rgb, 64, 158, 255), 0.12);
    border-color: rgba(var(--primary-rgb, 64, 158, 255), 0.25);
  }

  .pin-icon {
    flex-shrink: 0;
    width: 28px;
    height: 28px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--primary-color, #409eff);
    border-radius: 8px;

    svg {
      stroke: #fff;
    }
  }

  .pin-content {
    flex: 1;
    min-width: 0;

    .pin-label {
      font-size: 12px;
      color: var(--primary-color, #409eff);
      font-weight: 600;
      margin-bottom: 2px;
    }

    .pin-preview {
      font-size: 13px;
      color: #666;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
  }

  .pin-close {
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    transition: background-color 0.15s;

    svg {
      stroke: #999;
    }

    &:hover {
      background: rgba(0, 0, 0, 0.08);

      svg {
        stroke: #666;
      }
    }
  }
}
</style>
