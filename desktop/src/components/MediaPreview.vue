<template>
  <Teleport to="body">
    <div v-if="visible" class="media-preview-overlay" @click="handleOverlayClick">
    <div class="media-preview-container">
      <!-- 工具栏按钮 -->
      <div class="toolbar-buttons">
        <!-- 逆时针旋转按钮 -->
        <button v-if="mediaType === 'image'" class="toolbar-button" @click="rotateCounterClockwise" title="逆时针旋转">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M2.5 2v6h6M2.66 15.57a10 10 0 1 0 .57-8.38"/>
          </svg>
        </button>
        <!-- 顺时针旋转按钮 -->
        <button v-if="mediaType === 'image'" class="toolbar-button" @click="rotateClockwise" title="顺时针旋转">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38"/>
          </svg>
        </button>
        <!-- 关闭按钮 -->
        <button class="toolbar-button close-button" @click="close" title="关闭">
          <span class="close-icon">×</span>
        </button>
      </div>

      <!-- 图片预览 -->
      <div v-if="mediaType === 'image'" class="image-preview" @wheel.prevent="handleImageWheel">
        <img
          :src="mediaSrc"
          alt="图片预览"
          class="preview-image"
          :style="imageTransformStyle"
          @load="handleImageLoad"
          @error="handleImageError"
          @contextmenu.prevent="showContextMenu"
        />
      </div>

      <!-- 自定义右键菜单 -->
      <div
        v-if="contextMenuVisible"
        class="context-menu"
        :style="contextMenuStyle"
        @click.stop
      >
        <div class="context-menu-item" @click="handleForward">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z"/>
          </svg>
          <span>转发</span>
        </div>
        <div class="context-menu-item" @click="handleCopyImage">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
          </svg>
          <span>复制图片</span>
        </div>
        <div class="context-menu-item" @click="handleSaveAs">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
            <polyline points="7 10 12 15 17 10"/>
            <line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          <span>另存为</span>
        </div>
      </div>

      <!-- 视频预览 -->
      <div v-else-if="mediaType === 'video'" class="video-preview">
        <div class="custom-video-player">
          <video
            ref="videoElement"
            :src="mediaSrc"
            class="preview-video"
            :class="{ 'video-hidden': loading || !videoReady }"
            @loadstart="handleVideoLoadStart"
            @loadeddata="handleVideoLoadedData"
            @canplay="handleVideoCanPlay"
            @canplaythrough="handleVideoCanPlayThrough"
            @timeupdate="handleTimeUpdate"
            @ended="handleVideoEnded"
            @error="handleVideoError"
            @stalled="handleVideoStalled"
            @waiting="handleVideoWaiting"
            @contextmenu.prevent="showContextMenu"
            preload="auto"
            :loop="false"
          >
            您的浏览器不支持视频播放
          </video>

          <!-- 自定义视频控件 -->
          <div class="video-controls" v-show="!loading && videoReady">
            <!-- 播放/暂停按钮 -->
            <button class="play-button" @click="togglePlay">
              <!-- 暂停图标 -->
              <svg v-if="isPlaying" width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
              </svg>
              <!-- 播放图标 -->
              <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </button>

            <!-- 进度条容器 -->
            <div class="progress-container" @click="seekTo">
              <div class="progress-background">
                <div class="progress-buffer" :style="{ width: bufferProgress + '%' }"></div>
                <div class="progress-bar" :style="{ width: playProgress + '%' }"></div>
                <div
                  class="progress-thumb"
                  :style="{ left: playProgress + '%' }"
                  @mousedown="startDrag"
                ></div>
              </div>
            </div>

            <!-- 时间显示 -->
            <div class="time-display">
              <span class="current-time">{{ formatTime(currentTime) }}</span>
              <span class="separator">/</span>
              <span class="total-time">{{ formatTime(duration) }}</span>
            </div>

            <!-- 音量控制 -->
            <div class="volume-container">
              <button class="volume-button" @click="toggleMute">
                <span v-if="isMuted">🔇</span>
                <span v-else-if="volume > 0.5">🔊</span>
                <span v-else-if="volume > 0">🔉</span>
                <span v-else>🔈</span>
              </button>
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                v-model="volume"
                @input="updateVolume"
                class="volume-slider"
              />
            </div>

            <!-- 全屏按钮 -->
            <button class="fullscreen-button" @click="toggleFullscreen">
              <span v-if="isFullscreen">⛶</span>
              <span v-else>⛶</span>
            </button>
          </div>

          <!-- 视频加载动画 -->
          <div v-if="loading" class="video-loading-overlay">
            <div class="video-loading-spinner"></div>
            <div class="video-loading-text">视频加载中...</div>
          </div>

          <!-- 视频点击播放遮罩 -->
          <div v-if="!isPlaying && videoReady && !loading" class="video-click-overlay" @click="togglePlay">
            <div class="big-play-button">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, type CSSProperties } from 'vue'

interface Props {
  visible: boolean
  mediaSrc: string
  mediaType: 'image' | 'video'
  mediaName?: string
  mediaSize?: number
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  forward: []
  copySuccess: [message: string]
  copyError: [message: string]
  saveSuccess: [message: string]
  saveError: [message: string]
}>()

const loading = ref(true)

// 图片预览相关状态
const imageScale = ref(1)
const imageRotation = ref(0)
const MIN_SCALE = 0.1
const MAX_SCALE = 5

// 图片变换样式
const imageTransformStyle = computed(() => ({
  transform: `scale(${imageScale.value}) rotate(${imageRotation.value}deg)`,
  transition: 'transform 0.2s ease'
}))

// 鼠标滚轮缩放
const handleImageWheel = (event: WheelEvent) => {
  const delta = event.deltaY > 0 ? -0.1 : 0.1
  const newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, imageScale.value + delta))
  imageScale.value = newScale
}

// 顺时针旋转
const rotateClockwise = () => {
  imageRotation.value = (imageRotation.value + 90) % 360
}

// 逆时针旋转
const rotateCounterClockwise = () => {
  imageRotation.value = (imageRotation.value - 90 + 360) % 360
}

// 重置图片变换
const resetImageTransform = () => {
  imageScale.value = 1
  imageRotation.value = 0
}

// 右键菜单相关状态
const contextMenuVisible = ref(false)
const contextMenuX = ref(0)
const contextMenuY = ref(0)

const contextMenuStyle = computed(() => ({
  left: `${contextMenuX.value}px`,
  top: `${contextMenuY.value}px`
}))

// 显示右键菜单
const showContextMenu = (event: MouseEvent) => {
  contextMenuX.value = event.clientX
  contextMenuY.value = event.clientY
  contextMenuVisible.value = true
}

// 隐藏右键菜单
const hideContextMenu = () => {
  contextMenuVisible.value = false
}

// 转发功能
const handleForward = () => {
  hideContextMenu()
  emit('forward')
}

// 复制图片功能
const handleCopyImage = async () => {
  hideContextMenu()
  try {
    // 获取图片数据
    const response = await fetch(props.mediaSrc)
    const blob = await response.blob()

    // 使用 Clipboard API 复制图片
    await navigator.clipboard.write([
      new ClipboardItem({
        [blob.type]: blob
      })
    ])

    emit('copySuccess', '图片已复制到剪贴板')
  } catch (error) {
    console.error('复制图片失败:', error)
    emit('copyError', '复制图片失败')
  }
}

// 另存为功能
const handleSaveAs = async () => {
  hideContextMenu()
  try {
    // 获取图片数据
    const response = await fetch(props.mediaSrc)
    const blob = await response.blob()

    // 创建下载链接
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url

    // 从 mediaSrc 或 mediaName 获取文件名
    let filename = props.mediaName || 'image'
    if (!filename.includes('.')) {
      // 根据 blob 类型添加扩展名
      const ext = blob.type.split('/')[1] || 'png'
      filename = `${filename}.${ext}`
    }

    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)

    emit('saveSuccess', '图片已保存')
  } catch (error) {
    console.error('保存图片失败:', error)
    emit('saveError', '保存图片失败')
  }
}

// 视频播放器相关状态
const videoElement = ref<HTMLVideoElement | null>(null)
const videoReady = ref(false)
const isPlaying = ref(false)
const currentTime = ref(0)
const duration = ref(0)
const volume = ref(1)
const isMuted = ref(false)
const isFullscreen = ref(false)
const playProgress = ref(0)
const bufferProgress = ref(0)
const isDragging = ref(false)

// 格式化文件大小
const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

// 格式化时间
const formatTime = (seconds: number): string => {
  if (isNaN(seconds)) return '00:00'
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

// 关闭预览
const close = () => {
  if (videoElement.value) {
    videoElement.value.pause()
  }
  emit('close')
}

// 点击遮罩层关闭
const handleOverlayClick = (event: MouseEvent) => {
  // 先隐藏右键菜单
  if (contextMenuVisible.value) {
    hideContextMenu()
    return
  }
  if (event.target === event.currentTarget) {
    close()
  }
}

// 图片加载完成
const handleImageLoad = () => {
  loading.value = false
}

// 图片加载错误
const handleImageError = () => {
  loading.value = false
}

// 视频开始加载
const handleVideoLoadStart = () => {
  console.log('视频开始加载:', props.mediaSrc)
  loading.value = true
  videoReady.value = false
}

// 视频数据已加载
const handleVideoLoadedData = () => {
  console.log('视频数据已加载')
  if (videoElement.value) {
    duration.value = videoElement.value.duration || 0
    console.log('视频时长:', duration.value)
  }
}

// 视频可以播放
const handleVideoCanPlay = () => {
  console.log('视频可以播放')
  loading.value = false
  videoReady.value = true
  if (videoElement.value) {
    duration.value = videoElement.value.duration || 0
    volume.value = videoElement.value.volume
    isMuted.value = videoElement.value.muted

    // 自动播放视频
    videoElement.value.play().then(() => {
      console.log('视频自动播放成功')
      isPlaying.value = true
    }).catch(error => {
      console.warn('视频自动播放失败:', error)
      isPlaying.value = false
    })
  }
}

// 视频可以流畅播放
const handleVideoCanPlayThrough = () => {
  console.log('视频可以流畅播放')
  loading.value = false
  videoReady.value = true
}

// 时间更新
const handleTimeUpdate = () => {
  if (videoElement.value && !isDragging.value) {
    currentTime.value = videoElement.value.currentTime
    if (duration.value > 0) {
      playProgress.value = (currentTime.value / duration.value) * 100
    }

    // 更新缓冲进度
    const video = videoElement.value
    if (video.buffered.length > 0) {
      const buffered = video.buffered.end(video.buffered.length - 1)
      bufferProgress.value = (buffered / duration.value) * 100
    }
  }
}

// 视频播放结束
const handleVideoEnded = () => {
  isPlaying.value = false
  playProgress.value = 100
}

// 视频加载错误
const handleVideoError = (event: Event) => {
  const video = event.target as HTMLVideoElement
  const error = video.error
  console.error('视频加载错误:', {
    code: error?.code,
    message: error?.message,
    mediaSrc: props.mediaSrc,
    readyState: video.readyState,
    networkState: video.networkState
  })
  
  let errorMessage = '视频加载失败'
  if (error) {
    switch (error.code) {
      case MediaError.MEDIA_ERR_ABORTED:
        errorMessage = '视频加载被中止'
        break
      case MediaError.MEDIA_ERR_NETWORK:
        errorMessage = '网络错误，无法加载视频'
        break
      case MediaError.MEDIA_ERR_DECODE:
        errorMessage = '视频解码失败'
        break
      case MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED:
        errorMessage = '视频格式不支持'
        break
      default:
        errorMessage = `视频加载失败 (错误代码: ${error.code})`
    }
  }
  
  loading.value = false
  videoReady.value = false
  // 显示错误信息（可以通过 emit 传递给父组件，或者在这里显示）
  console.error(errorMessage)
}

// 视频加载停滞
const handleVideoStalled = () => {
  console.warn('视频加载停滞')
}

// 视频等待数据
const handleVideoWaiting = () => {
  console.log('视频等待数据中...')
  loading.value = true
}

// 播放/暂停切换
const togglePlay = () => {
  if (!videoElement.value) return

  if (videoElement.value.paused) {
    videoElement.value.play()
    isPlaying.value = true
  } else {
    videoElement.value.pause()
    isPlaying.value = false
  }
}

// 进度条点击跳转
const seekTo = (event: MouseEvent) => {
  if (!videoElement.value || !duration.value) return

  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  const percent = (event.clientX - rect.left) / rect.width
  const seekTime = percent * duration.value

  videoElement.value.currentTime = seekTime
  currentTime.value = seekTime
  playProgress.value = percent * 100
}

// 开始拖拽进度条
const startDrag = (event: MouseEvent) => {
  isDragging.value = true
  event.preventDefault()

  const handleMouseMove = (moveEvent: MouseEvent) => {
    if (!videoElement.value || !duration.value) return

    const container = document.querySelector('.progress-container') as HTMLElement
    if (!container) return

    const rect = container.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (moveEvent.clientX - rect.left) / rect.width))
    const seekTime = percent * duration.value

    videoElement.value.currentTime = seekTime
    currentTime.value = seekTime
    playProgress.value = percent * 100
  }

  const handleMouseUp = () => {
    isDragging.value = false
    document.removeEventListener('mousemove', handleMouseMove)
    document.removeEventListener('mouseup', handleMouseUp)
  }

  document.addEventListener('mousemove', handleMouseMove)
  document.addEventListener('mouseup', handleMouseUp)
}

// 更新音量
const updateVolume = () => {
  if (videoElement.value) {
    videoElement.value.volume = volume.value
    if (volume.value > 0) {
      isMuted.value = false
      videoElement.value.muted = false
    }
  }
}

// 静音切换
const toggleMute = () => {
  if (!videoElement.value) return

  if (isMuted.value) {
    videoElement.value.muted = false
    isMuted.value = false
  } else {
    videoElement.value.muted = true
    isMuted.value = true
  }
}

// 全屏切换
const toggleFullscreen = () => {
  if (!videoElement.value) return

  if (document.fullscreenElement) {
    document.exitFullscreen()
    isFullscreen.value = false
  } else {
    const playerContainer = videoElement.value.closest('.custom-video-player') as HTMLElement
    if (playerContainer) {
      playerContainer.requestFullscreen()
      isFullscreen.value = true
    }
  }
}

// 监听 visible 变化，重置状态
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    loading.value = true
    videoReady.value = false
    isPlaying.value = false
    currentTime.value = 0
    duration.value = 0
    playProgress.value = 0
    bufferProgress.value = 0
    // 重置图片变换
    resetImageTransform()
    // 重置右键菜单
    hideContextMenu()

    // 如果视频元素存在，重新加载视频
    if (videoElement.value && props.mediaSrc) {
      console.log('预览打开，重新加载视频:', props.mediaSrc)
      videoElement.value.load()
    }
  } else {
    // 关闭时暂停视频
    if (videoElement.value) {
      videoElement.value.pause()
      isPlaying.value = false
    }
    // 关闭时重置图片变换
    resetImageTransform()
    // 关闭时隐藏右键菜单
    hideContextMenu()
  }
})

// 监听 mediaSrc 变化，重新加载视频
watch(() => props.mediaSrc, (newSrc, oldSrc) => {
  if (newSrc && newSrc !== oldSrc && videoElement.value) {
    console.log('视频源变化，重新加载:', { oldSrc, newSrc })
    loading.value = true
    videoReady.value = false
    isPlaying.value = false
    videoElement.value.load()
  }
})

// 键盘事件监听（ESC 关闭，空格播放/暂停）
const handleKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape') {
    close()
  } else if (event.key === ' ' || event.key === 'Spacebar') {
    event.preventDefault()
    togglePlay()
  }
}

// 全屏状态监听
const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement
}

// 组件挂载时添加监听器
onMounted(() => {
  document.addEventListener('fullscreenchange', handleFullscreenChange)
})

// 组件卸载时清理监听器
onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange)
})

// 监听visible变化添加/移除键盘监听
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    document.addEventListener('keydown', handleKeydown)
  } else {
    document.removeEventListener('keydown', handleKeydown)
  }
})
</script>

<style scoped lang="scss">
.media-preview-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 99999;
  backdrop-filter: blur(8px);
  animation: fadeIn 0.2s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.media-preview-container {
  position: relative;
  max-width: 90vw;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.toolbar-buttons {
  align-self: flex-end;
  margin-bottom: 12px;
  display: flex;
  gap: 8px;
  z-index: 10001;
}

.toolbar-button {
  width: 40px;
  height: 40px;
  background-color: rgba(255, 255, 255, 0.2);
  border: none;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
  cursor: pointer;
  color: white;

  &:hover {
    background-color: rgba(255, 255, 255, 0.3);
  }

  &.close-button {
    .close-icon {
      font-size: 24px;
      font-weight: bold;
      line-height: 1;
    }
  }

  svg {
    stroke: white;
  }
}

.context-menu {
  position: fixed;
  background: rgba(40, 40, 40, 0.95);
  border-radius: 8px;
  padding: 6px 0;
  min-width: 140px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  z-index: 100002;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  animation: contextMenuFadeIn 0.15s ease-out;

  .context-menu-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 16px;
    color: rgba(255, 255, 255, 0.9);
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.15s;

    &:hover {
      background-color: rgba(255, 255, 255, 0.1);
    }

    &:active {
      background-color: rgba(255, 255, 255, 0.15);
    }

    svg {
      stroke: rgba(255, 255, 255, 0.8);
      flex-shrink: 0;
    }

    span {
      white-space: nowrap;
    }
  }
}

@keyframes contextMenuFadeIn {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.image-preview {
  display: flex;
  flex-direction: column;
  align-items: center;

  .preview-image {
    max-width: 90vw;
    max-height: 80vh;
    object-fit: contain;
    border-radius: 8px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
  }
}

.video-preview {
  display: flex;
  flex-direction: column;
  align-items: center;

  .custom-video-player {
    position: relative;
    background: #000;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    min-width: 400px; /* 最小宽度确保加载动画有足够空间 */
    min-height: 300px; /* 最小高度确保加载动画有足够空间 */

    .preview-video {
      max-width: 90vw;
      max-height: 80vh;
      width: auto;
      height: auto;
      display: block;
      background: #000;
      transition: opacity 0.3s ease, visibility 0.3s ease;

      /* 完全隐藏原生控件 */
      &::-webkit-media-controls {
        display: none !important;
      }

      &::-webkit-media-controls-panel {
        display: none !important;
      }

      &::-webkit-media-controls-play-button {
        display: none !important;
      }

      &::-webkit-media-controls-start-playback-button {
        display: none !important;
      }

      /* 加载中时隐藏视频元素 */
      &.video-hidden {
        opacity: 0;
        visibility: hidden;
      }
    }

    /* 自定义控件栏 */
    .video-controls {
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      background: linear-gradient(to top, rgba(0, 0, 0, 0.8), transparent);
      padding: 20px 16px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      opacity: 0;
      transition: opacity 0.3s ease;

      &:hover {
        opacity: 1;
      }
    }

    &:hover .video-controls {
      opacity: 1;
    }

    /* 播放按钮 */
    .play-button {
      background: $primary-color; /* 使用全局主色调 */
      border: none;
      color: white;
      font-size: 20px;
      padding: 12px;
      border-radius: 50%;
      width: 48px;
      height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
      box-shadow: 0 4px 12px rgba(78, 205, 196, 0.3); /* 主色调阴影 */

      &:hover {
        background: $primary-dark;
        transform: scale(1.05);
        box-shadow: 0 6px 16px rgba(78, 205, 196, 0.4);
      }

      &:active {
        transform: scale(0.95);
      }
    }

    /* 进度条容器 */
    .progress-container {
      flex: 1;
      height: 24px; /* 增加高度便于交互 */
      display: flex;
      align-items: center;
      padding: 0 8px; /* 增加左右间距 */

      .progress-background {
        position: relative;
        width: 100%;
        height: 6px; /* 增加高度 */
        background-color: rgba(255, 255, 255, 0.2);
        border-radius: 3px;
        overflow: hidden;
        transition: height 0.2s ease;

        .progress-buffer {
          position: absolute;
          top: 0;
          left: 0;
          height: 100%;
          background-color: rgba(255, 255, 255, 0.4);
          border-radius: 3px;
          transition: width 0.3s ease;
        }

        .progress-bar {
          position: absolute;
          top: 0;
          left: 0;
          height: 100%;
          background: $gradient-primary; /* 使用全局主色调渐变 */
          border-radius: 3px;
          transition: width 0.15s ease;
          box-shadow: 0 2px 8px rgba(78, 205, 196, 0.3);
        }

        .progress-thumb {
          position: absolute;
          top: 50%;
          transform: translate(-50%, -50%);
          width: 16px;
          height: 16px;
          background: $primary-color;
          border: 2px solid white;
          border-radius: 50%;
          opacity: 0;
          transition: all 0.2s ease;
          box-shadow: 0 2px 8px rgba(78, 205, 196, 0.4);

          &:hover {
            transform: translate(-50%, -50%) scale(1.2);
          }
        }

        &:hover {
          height: 8px; /* 悬停时高度增加 */

          .progress-thumb {
            opacity: 1;
          }
        }
      }
    }

    /* 时间显示 */
    .time-display {
      color: white;
      font-size: 13px;
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 6px;
      min-width: 90px;
      background: rgba(0, 0, 0, 0.3);
      padding: 6px 10px;
      border-radius: 12px;

      .separator {
        opacity: 0.6;
        font-weight: 300;
      }
    }

    /* 音量控制 */
    .volume-container {
      display: flex;
      align-items: center;
      gap: 8px;

      .volume-button {
        background: rgba(255, 255, 255, 0.1);
        border: none;
        color: white;
        font-size: 16px;
        padding: 8px;
        border-radius: 50%;
        width: 36px;
        height: 36px;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;

        &:hover {
          background: $primary-color;
          transform: scale(1.05);
        }
      }

      .volume-slider {
        width: 70px;
        height: 6px;
        background: rgba(255, 255, 255, 0.2);
        border-radius: 3px;
        outline: none;
        appearance: none;

        &::-webkit-slider-thumb {
          appearance: none;
          width: 14px;
          height: 14px;
          background: $primary-color;
          border: 2px solid white;
          border-radius: 50%;
          box-shadow: 0 2px 8px rgba(78, 205, 196, 0.3);
          transition: transform 0.2s ease;

          &:hover {
            transform: scale(1.2);
          }
        }

        &::-moz-range-thumb {
          width: 14px;
          height: 14px;
          background: $primary-color;
          border: 2px solid white;
          border-radius: 50%;
          box-shadow: 0 2px 8px rgba(78, 205, 196, 0.3);
        }

        &::-webkit-slider-track {
          background: rgba(255, 255, 255, 0.2);
          border-radius: 3px;
        }
      }
    }

    /* 全屏按钮 */
    .fullscreen-button {
      background: rgba(255, 255, 255, 0.1);
      border: none;
      color: white;
      font-size: 16px;
      padding: 8px;
      border-radius: 50%;
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;

      &:hover {
        background: $primary-color;
        transform: scale(1.05);
      }
    }

    /* 视频加载动画 */
    .video-loading-overlay {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.8);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: white;

      .video-loading-spinner {
        width: 60px;
        height: 60px;
        border: 4px solid rgba(255, 255, 255, 0.2);
        border-top: 4px solid $primary-color; /* 主色调 */
        border-right: 4px solid $secondary-color; /* 辅色调 */
        border-radius: 50%;
        animation: videoSpin 1s linear infinite;
        margin-bottom: 20px;
        box-shadow: 0 4px 16px rgba(78, 205, 196, 0.3);
      }

      .video-loading-text {
        font-size: 16px;
        opacity: 0.9;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.9);
      }
    }

    /* 大播放按钮 */
    .video-click-overlay {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(0, 0, 0, 0.2);
      transition: all 0.3s ease;

      &:hover {
        background: rgba(0, 0, 0, 0.4);
      }

      .big-play-button {
        width: 80px;
        height: 80px;
        background: rgba(255, 255, 255, 0.9); /* 白色背景 */
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: $primary-color; /* 主色调图标 */
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
        transition: all 0.3s ease;
        border: 3px solid rgba(255, 255, 255, 1);

        &:hover {
          transform: scale(1.1);
          box-shadow: 0 12px 32px rgba(0, 0, 0, 0.4);
          background: rgba(255, 255, 255, 1);
        }

        &:active {
          transform: scale(1.05);
        }

        /* 移除重复的播放图标 */
        &::before {
          display: none;
        }

        /* SVG图标样式 */
        svg {
          margin-left: 2px; /* 视觉居中调整 */
        }
      }
    }
  }
}

@keyframes videoSpin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.media-info {
  margin-top: 16px;
  text-align: center;
  color: white;

  .media-name {
    font-size: 16px;
    font-weight: 500;
    margin-bottom: 8px;
    word-break: break-all;
  }

  .media-size {
    font-size: 14px;
    opacity: 0.8;
  }
}

.loading-overlay {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  color: white;

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255, 255, 255, 0.3);
    border-top: 3px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 16px;
  }

  .loading-text {
    font-size: 16px;
    opacity: 0.8;
  }
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
