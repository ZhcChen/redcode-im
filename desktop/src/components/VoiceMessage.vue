<template>
  <!-- 播放模式 -->
  <div
    v-if="!showRecorder"
    class="voice-message"
    :class="{ 'is-mine': isMine, 'no-url': !playableUrl }"
    :style="{ width: containerWidth + 'px' }"
    @click="handleClick"
  >
    <!-- 播放/暂停按钮 -->
    <div class="play-button">
      <div v-if="isLoading" class="loading-spinner"></div>
      <div v-else-if="!playableUrl" class="retry-button" @click.stop="retryLoad" title="点击重试">
        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12,4C7.58,4 4,6.58 4,11C4,13.57 4.87,15.96 6.08,17.86L7.14,16.8C6.21,15.19 5.6,13.21 5.6,11.2C5.6,7.79 8.26,5.2 12,5.2C13.58,5.2 15.08,5.55 16.43,6.16L14.89,7.7C13.95,7.28 12.99,7.06 12,7.06C9.2,7.06 7,8.79 7,11.2C7,13.21 7.95,15.53 8.99,17.17C9.79,18.42 10.86,19.5 12,20.47V22H18V18.5C18,14.92 15.39,12 12,12V8.27L15.14,11.41C16.62,9.85 17.54,7.8 17.54,5.67C17.54,4.69 17.34,3.74 17,2.9L18.35,1.55C19.05,3.18 19.4,4.98 19.4,6.8C19.4,9.8 18.6,12.6 17.2,14.9L15.3,13C16.4,11.3 17.1,9.2 17.1,7C17.1,6.3 17.04,5.63 16.93,5H21L18.5,7.5L21,10V10.5L19,8.5L17,10.5V9.5L19,7.5V7C19,4.58 17.17,2.6 14.9,2.05C13.9,1.84 12.9,2.08 12,2.63V2V4Z"/>
        </svg>
      </div>
      <svg v-else-if="isPlaying" class="icon" viewBox="0 0 24 24" fill="currentColor">
        <rect x="6" y="5" width="4" height="14" rx="1" />
        <rect x="14" y="5" width="4" height="14" rx="1" />
      </svg>
      <svg v-else class="icon" viewBox="0 0 24 24" fill="currentColor">
        <path d="M8 5.14v14l11-7-11-7z" />
      </svg>
    </div>

    <!-- 波形进度条 -->
    <div v-if="playableUrl" class="waveform">
      <div
        v-for="(height, index) in waveHeights"
        :key="index"
        class="wave-bar"
        :class="{ played: isBarPlayed(index) }"
        :style="{ height: getBarHeight(height) + 'px' }"
      ></div>
    </div>
    <div v-else class="no-url-text">
      <span v-if="isLoading">加载中...</span>
      <span v-else>文件缺失</span>
    </div>

    <!-- 时长 -->
    <div class="duration">{{ formattedDuration }}</div>
  </div>

  <!-- 录音模式 -->
  <div v-else class="voice-recorder">
    <!-- 录音状态显示 -->
    <div class="recorder-status" v-if="isRecording">
      <div class="recording-indicator"></div>
      <span class="recording-text">正在录音 {{ recordingDurationFormatted }}</span>
    </div>
    <div class="recorder-hint" v-else-if="!previewRecording">
      点击开始录音
    </div>

    <!-- 预览模式 -->
    <div class="preview-container" v-if="previewRecording">
      <div class="preview-player" @click="playPreview">
        <div class="play-button">
          <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
            <path d="M8 5.14v14l11-7-11-7z" />
          </svg>
        </div>
        <div class="waveform">
          <div
            v-for="(height, index) in previewWaveHeights"
            :key="index"
            class="wave-bar"
            :style="{ height: (16 * height) + 'px' }"
          ></div>
        </div>
        <div class="duration">{{ VoiceUtils.formatDuration(previewRecording.duration) }}</div>
      </div>
    </div>

    <!-- 控制按钮 -->
    <div class="recorder-controls">
      <!-- 取消按钮 -->
      <button class="control-btn cancel-btn" @click="handleCancel">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
        </svg>
      </button>

      <!-- 录音按钮 -->
      <button
        class="control-btn record-btn"
        :class="{ recording: isRecording }"
        @click="toggleRecord"
      >
        <svg v-if="isRecording" viewBox="0 0 24 24" fill="currentColor">
          <rect x="6" y="6" width="12" height="12" rx="2" />
        </svg>
        <svg v-else viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
          <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
        </svg>
      </button>

      <!-- 发送按钮 -->
      <button
        class="control-btn send-btn"
        :class="{ active: previewRecording }"
        @click="sendVoice"
        :disabled="!previewRecording"
      >
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
        </svg>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { VoiceRecorder, VoicePlayer, VoiceUtils, type VoiceRecording } from '../utils/voiceRecorder'
import { toast } from '@/utils/toast'

// Props
interface Props {
  voiceUrl?: string
  duration?: number  // 毫秒
  isMine?: boolean
  autoplay?: boolean
  showRecorder?: boolean
  messageId?: string
}

const props = withDefaults(defineProps<Props>(), {
  voiceUrl: '',
  duration: 0,
  isMine: false,
  autoplay: false,
  showRecorder: false,
  messageId: ''
})

// Emits
const emit = defineEmits<{
  voiceSend: [recording: VoiceRecording]
  voiceCancel: []
}>()

// 响应式数据
const isPlaying = ref(false)
const isLoading = ref(false)
const animationFrame = ref<number | null>(null)
const waveAnimationValue = ref(0.5)
const isRecording = ref(false)
const recordingStartTime = ref(0)
const recordingDuration = ref(0)
const previewRecording = ref<VoiceRecording | null>(null)
const playProgress = ref(0) // 播放进度 0.0 - 1.0
const effectiveDuration = ref(props.duration || 0) // 毫秒，优先用元数据兜底
const playableUrl = ref(props.voiceUrl || '')

// 默认波形基础高度（12条波形），用于无实际波形数据时的占位
const defaultBaseHeights = [0.4, 0.7, 0.5, 0.8, 0.6, 0.9, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5]
const barCount = defaultBaseHeights.length

// 实例
const voicePlayer = new VoicePlayer()
const voiceRecorder = new VoiceRecorder()
let recordingTimer: number | null = null

// 设置播放结束回调
voicePlayer.onEnded(() => {
  console.log('[VoiceMessage] 播放结束回调触发')
  isPlaying.value = false
  playProgress.value = 0
  if (animationFrame.value) {
    cancelAnimationFrame(animationFrame.value)
    animationFrame.value = null
  }
  waveAnimationValue.value = 0.5
})

// 设置播放进度回调
voicePlayer.onProgress((progress: number) => {
  playProgress.value = progress
})

// 计算属性
const isSupported = computed(() => VoiceRecorder.isSupported())

const formattedDuration = computed(() => {
  const secondsRaw = effectiveDuration.value / 1000
  const seconds = Number.isFinite(secondsRaw) ? Math.max(0, Math.floor(secondsRaw)) : 0
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
})

const recordingDurationFormatted = computed(() => {
  return VoiceUtils.formatDuration(recordingDuration.value)
})

// 根据时长计算宽度（最小100，最大200）
const containerWidth = computed(() => {
  const width = 100 + (effectiveDuration.value / 1000) * 3
  return Math.max(100, Math.min(200, width))
})

// 播放模式下使用固定波形
const waveHeights = computed(() => defaultBaseHeights)

// 录音预览波形：优先使用录音结果中携带的 waveform 数据，否则按默认占位波形生成
const previewWaveHeights = computed(() => {
  if (previewRecording.value?.waveform && previewRecording.value.waveform.length > 0) {
    return previewRecording.value.waveform.map((v) => Math.max(0.2, Math.min(1, v)))
  }
  return defaultBaseHeights
})

const getBarHeight = (baseHeight: number): number => {
  const maxHeight = 16
  if (isPlaying.value) {
    return maxHeight * baseHeight * (0.5 + waveAnimationValue.value * 0.5)
  }
  return maxHeight * baseHeight * 0.5
}

// 判断某个波形条是否已播放
const isBarPlayed = (index: number): boolean => {
  const barProgress = (index + 1) / barCount
  return barProgress <= playProgress.value
}

// 波形动画
let animationDirection = 1
const animateWave = () => {
  if (!isPlaying.value) return

  waveAnimationValue.value += 0.03 * animationDirection
  if (waveAnimationValue.value >= 1) {
    animationDirection = -1
  } else if (waveAnimationValue.value <= 0) {
    animationDirection = 1
  }

  animationFrame.value = requestAnimationFrame(animateWave)
}

// 统一的点击处理方法
const handleClick = () => {
  if (playableUrl.value) {
    togglePlay()
  } else {
    retryLoad()
  }
}

// 重试加载方法
const retryLoad = () => {
  if (isLoading.value) return
  console.log('[VoiceMessage] 手动重试加载语音', { messageId: props.messageId, rawUrl: props.voiceUrl })
  isLoading.value = true
  // 重新加载元数据
  watch(() => props.voiceUrl, async (url) => {
    if (!url) {
      isLoading.value = false
      return
    }
    playableUrl.value = url
    try {
      const playable = VoicePlayer.toPlayableUrl(url)
      playableUrl.value = playable
      const audio = new Audio()
      audio.preload = 'metadata'
      audio.src = playable
      audio.onloadedmetadata = () => {
        if (!isNaN(audio.duration) && audio.duration > 0) {
          const durationMs = Math.round(audio.duration * 1000)
          if (durationMs > 0) {
            effectiveDuration.value = durationMs
          }
        }
        console.log('[VoiceMessage] 预加载元数据', { url: playable, duration: audio.duration })
        isLoading.value = false
      }
      audio.onerror = () => {
        console.warn('[VoiceMessage] 元数据加载失败', { url: playable })
        isLoading.value = false
      }
      audio.load()
    } catch (error) {
      console.error('[VoiceMessage] 加载失败', error)
      isLoading.value = false
    }
  }, { immediate: true })()
}

// 播放方法
const togglePlay = async () => {
  if (!playableUrl.value || isLoading.value) {
    console.warn('[VoiceMessage] 无可播放的语音 URL，取消播放', {
      messageId: props.messageId,
      rawUrl: props.voiceUrl,
      playableUrl: playableUrl.value,
      duration: effectiveDuration.value
    })
    return
  }

  try {
    if (isPlaying.value) {
      voicePlayer.pause()
      isPlaying.value = false
      if (animationFrame.value) {
        cancelAnimationFrame(animationFrame.value)
        animationFrame.value = null
      }
    } else {
      isLoading.value = true
      // 注意：play() 返回的 Promise 在播放结束时才 resolve
      // 我们不需要 await 完整播放过程，只需要开始播放即可
      voicePlayer.play(playableUrl.value).catch((err: any) => {
        console.error('播放失败:', err)
        isPlaying.value = false
        isLoading.value = false
      })
      // 短暂延迟后检查是否开始播放，然后更新状态
      setTimeout(() => {
        if (voicePlayer.isPlaying()) {
          isLoading.value = false
          isPlaying.value = true
          animateWave()
        }
      }, 100)
    }
  } catch (err: any) {
    console.error('播放失败:', err)
    isPlaying.value = false
    isLoading.value = false
  }
}

// 录音方法
const toggleRecord = async () => {
  try {
    if (isRecording.value) {
      // 停止录音
      const recording = await voiceRecorder.stopRecording()
      previewRecording.value = recording
      isRecording.value = false
      if (recordingTimer) {
        clearInterval(recordingTimer)
        recordingTimer = null
      }
    } else {
      // 开始录音
      const hasPermission = await VoiceRecorder.requestPermission()
      if (!hasPermission) {
        throw new Error('无法获取麦克风权限')
      }

      await voiceRecorder.startRecording()
      isRecording.value = true
      recordingStartTime.value = Date.now()
      recordingDuration.value = 0

      // 更新录音时长
      recordingTimer = window.setInterval(() => {
        recordingDuration.value = (Date.now() - recordingStartTime.value) / 1000
      }, 100)
    }
  } catch (err: any) {
    console.error('录音失败:', err)
    isRecording.value = false
    const message = err?.message || '录音失败，请检查麦克风权限或设备设置'
    toast.error(message)
  }
}

const handleCancel = () => {
  if (isRecording.value) {
    voiceRecorder.cancelRecording()
    isRecording.value = false
    if (recordingTimer) {
      clearInterval(recordingTimer)
      recordingTimer = null
    }
  }
  previewRecording.value = null
  emit('voiceCancel')
}

const playPreview = async () => {
  if (!previewRecording.value) return
  try {
    await voicePlayer.play(previewRecording.value.url)
  } catch (err) {
    console.error('预览播放失败:', err)
  }
}

const sendVoice = () => {
  if (previewRecording.value) {
    emit('voiceSend', previewRecording.value)
    previewRecording.value = null
  }
}

// 监听播放结束
watch(isPlaying, (playing) => {
  if (!playing && animationFrame.value) {
    cancelAnimationFrame(animationFrame.value)
    animationFrame.value = null
    waveAnimationValue.value = 0.5
  }
})

// 当传入的 voiceUrl 变化时，尝试预加载元数据并更新时长
watch(() => props.voiceUrl, async (url) => {
  if (!url) return
  playableUrl.value = url
  try {
    const playable = VoicePlayer.toPlayableUrl(url)
    playableUrl.value = playable
    const audio = new Audio()
    audio.preload = 'metadata'
    audio.src = playable
    audio.onloadedmetadata = () => {
      if (!isNaN(audio.duration) && audio.duration > 0) {
        const durationMs = Math.round(audio.duration * 1000)
        if (durationMs > 0) {
          effectiveDuration.value = durationMs
        }
      }
      console.log('[VoiceMessage] 预加载元数据', { url: playable, duration: audio.duration })
    }
    audio.onerror = () => {
      console.warn('[VoiceMessage] 元数据加载失败', { url: playable })
    }
    audio.load()
  } catch (error) {
    // 静默
  }
}, { immediate: true })

// 当外部 props.duration 变化时，同步到有效时长
watch(() => props.duration, (newVal) => {
  if (newVal && newVal > 0) {
    effectiveDuration.value = newVal
  }
})

// 生命周期
onMounted(() => {
  if (props.autoplay && props.voiceUrl) {
    setTimeout(() => {
      togglePlay()
    }, 100)
  }
})

onUnmounted(() => {
  voicePlayer.destroy()
  voiceRecorder.destroy()
  if (animationFrame.value) {
    cancelAnimationFrame(animationFrame.value)
  }
  if (recordingTimer) {
    clearInterval(recordingTimer)
  }
  if (previewRecording.value?.url) {
    URL.revokeObjectURL(previewRecording.value.url)
  }
})
</script>

<style lang="scss" scoped>
$primary-color: #00C2B3;
$text-primary: #2C2D3A;
$danger-color: #F6695E;

.voice-message {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 16px;
  cursor: pointer;
  transition: all 0.2s;
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);

  &:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  &.no-url {
    cursor: pointer;

    .retry-button {
      color: #9CA0B4;
      cursor: pointer;
      transition: all 0.2s;

      &:hover {
        color: $primary-color;
        transform: scale(1.1);
      }
    }

    .no-url-text {
      flex: 1;
      font-size: 12px;
      color: #9CA0B4;
      text-align: center;
    }
  }

  &.is-mine {
    background: $primary-color;

    .play-button {
      color: #fff;
    }

    .waveform .wave-bar {
      background: rgba(255, 255, 255, 0.3);

      &.played {
        background: #fff;
      }
    }

    .duration {
      color: rgba(255, 255, 255, 0.7);
    }

    .loading-spinner {
      border-color: rgba(255, 255, 255, 0.3);
      border-top-color: #fff;
    }
  }
}

.play-button {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: $primary-color;
  flex-shrink: 0;

  .icon {
    width: 24px;
    height: 24px;
  }
}

.loading-spinner {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(0, 194, 179, 0.3);
  border-top-color: $primary-color;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.waveform {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-evenly;
  height: 20px;
  gap: 2px;
}

.wave-bar {
  width: 2px;
  background: rgba(44, 45, 58, 0.3);
  border-radius: 1px;
  transition: height 0.1s ease, background 0.1s ease;

  &.played {
    background: $primary-color;
  }
}

.duration {
  font-size: 12px;
  color: rgba(44, 45, 58, 0.7);
  flex-shrink: 0;
  min-width: 32px;
  text-align: right;
}

// 录音模式样式
.voice-recorder {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px;
  gap: 20px;
}

.recorder-status {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  font-weight: 500;
  color: $text-primary;
}

.recording-indicator {
  width: 12px;
  height: 12px;
  background: $danger-color;
  border-radius: 50%;
  animation: pulse 1s infinite;
  box-shadow: 0 0 8px rgba(246, 105, 94, 0.5);
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.recorder-hint {
  font-size: 14px;
  color: #9CA0B4;
}

.preview-container {
  width: 100%;
}

.preview-player {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 16px;
  background: #F4F5F6;
  cursor: pointer;
  width: 180px;
  margin: 0 auto;

  .play-button {
    color: $primary-color;
  }

  .wave-bar {
    background: rgba(44, 45, 58, 0.3);
  }
}

.recorder-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 24px;
}

.control-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  transition: all 0.2s;

  svg {
    width: 24px;
    height: 24px;
  }

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
}

.cancel-btn {
  width: 48px;
  height: 48px;
  background: #F4F5F6;
  color: #9CA0B4;

  &:hover:not(:disabled) {
    background: #E5E8EC;
    color: $text-primary;
  }
}

.record-btn {
  width: 64px;
  height: 64px;
  background: $primary-color;
  color: #fff;
  box-shadow: 0 4px 12px rgba(0, 194, 179, 0.3);

  &:hover:not(:disabled) {
    transform: scale(1.05);
    box-shadow: 0 6px 16px rgba(0, 194, 179, 0.4);
  }

  &.recording {
    background: $danger-color;
    box-shadow: 0 4px 12px rgba(246, 105, 94, 0.3);

    &:hover:not(:disabled) {
      box-shadow: 0 6px 16px rgba(246, 105, 94, 0.4);
    }
  }

  svg {
    width: 28px;
    height: 28px;
  }
}

.send-btn {
  width: 48px;
  height: 48px;
  background: #F4F5F6;
  color: #9CA0B4;

  &:hover:not(:disabled) {
    background: #E5E8EC;
  }

  &.active {
    background: $primary-color;
    color: #fff;
    box-shadow: 0 4px 12px rgba(0, 194, 179, 0.3);

    &:hover:not(:disabled) {
      box-shadow: 0 6px 16px rgba(0, 194, 179, 0.4);
    }
  }
}
</style>
