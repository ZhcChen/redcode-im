<template>
  <div class="voice-message">
    <!-- 语音播放器 -->
    <div class="voice-player" v-if="voiceUrl">
      <div class="voice-controls">
        <button
          class="play-button"
          @click="togglePlay"
          :disabled="isLoading"
        >
          <img
            :src="isPlaying ? pauseIcon : playIcon"
            :alt="isPlaying ? '暂停' : '播放'"
            class="control-icon"
          />
        </button>

        <div class="voice-info">
          <div class="voice-duration">{{ formattedDuration }}</div>
          <div class="voice-progress" v-if="isPlaying">
            <div class="progress-bar">
              <div
                class="progress-fill"
                :style="{ width: progressPercentage + '%' }"
              ></div>
            </div>
            <div class="time-display">
              {{ currentTimeFormatted }} / {{ formattedDuration }}
            </div>
          </div>
        </div>

        <div class="voice-volume">
          <input
            type="range"
            min="0"
            max="100"
            :value="volume * 100"
            @input="handleVolumeChange"
            class="volume-slider"
          />
        </div>
      </div>
    </div>

    <!-- 语音录制器 -->
    <div class="voice-recorder" v-if="showRecorder">
      <div class="recorder-controls">
        <button
          class="record-button"
          @click="toggleRecord"
          :class="{ recording: isRecording }"
          :disabled="!isSupported"
        >
          <img
            :src="isRecording ? stopIcon : recordIcon"
            :alt="isRecording ? '停止录音' : '开始录音'"
            class="control-icon"
          />
        </button>

        <div class="recorder-info">
          <div class="recording-status" v-if="isRecording">
            <span class="recording-indicator">🔴</span>
            录音中... {{ recordingDurationFormatted }}
          </div>
          <div class="recording-placeholder" v-else>
            点击开始录音
          </div>
        </div>

        <button
          class="cancel-button"
          v-if="isRecording"
          @click="cancelRecording"
        >
          取消
        </button>
      </div>
    </div>

    <!-- 语音预览 -->
    <div class="voice-preview" v-if="previewRecording">
      <div class="preview-controls">
        <button class="play-button" @click="playPreview">
          <img :src="playIcon" alt="播放" class="control-icon" />
        </button>

        <div class="preview-info">
          <div class="preview-duration">{{ VoiceUtils.formatDuration(previewRecording.duration) }}</div>
          <div class="preview-size">{{ VoiceUtils.getAudioSize(previewRecording.blob) }}</div>
        </div>

        <div class="preview-actions">
          <button class="send-button" @click="sendVoice">
            发送
          </button>
          <button class="delete-button" @click="deletePreview">
            删除
          </button>
        </div>
      </div>
    </div>

    <!-- 错误提示 -->
    <div class="voice-error" v-if="error">
      <span class="error-icon">⚠️</span>
      <span class="error-message">{{ error }}</span>
      <button class="retry-button" @click="retry" v-if="canRetry">
        重试
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { VoiceRecorder, VoicePlayer, VoiceUtils, type VoiceRecording } from '../utils/voiceRecorder'

// Props
interface Props {
  voiceUrl?: string
  duration?: number
  showRecorder?: boolean
  autoplay?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  voiceUrl: '',
  duration: 0,
  showRecorder: false,
  autoplay: false,
})

// Emits
const emit = defineEmits<{
  voiceSend: [recording: VoiceRecording]
  voiceCancel: []
}>()

// 响应式数据
const isPlaying = ref(false)
const isLoading = ref(false)
const currentTime = ref(0)
const duration = ref(props.duration || 0)
const volume = ref(0.8)
const isRecording = ref(false)
const recordingStartTime = ref(0)
const previewRecording = ref<VoiceRecording | null>(null)
const error = ref<string>('')
const canRetry = ref(false)

// 实例
const voicePlayer = new VoicePlayer()
const voiceRecorder = new VoiceRecorder()

// 计算属性
const isSupported = computed(() => VoiceRecorder.isSupported())

const formattedDuration = computed(() => {
  return VoiceUtils.formatDuration(duration.value)
})

const currentTimeFormatted = computed(() => {
  return VoiceUtils.formatDuration(currentTime.value)
})

const progressPercentage = computed(() => {
  return duration.value > 0 ? (currentTime.value / duration.value) * 100 : 0
})

const recordingDuration = computed(() => {
  if (!isRecording.value) return 0
  return (Date.now() - recordingStartTime.value) / 1000
})

const recordingDurationFormatted = computed(() => {
  return VoiceUtils.formatDuration(recordingDuration.value)
})

// 图标
const playIcon = '/icons/play.svg'
const pauseIcon = '/icons/pause.svg'
const recordIcon = '/icons/record.svg'
const stopIcon = '/icons/stop.svg'

// 方法
const togglePlay = async () => {
  if (!props.voiceUrl) return

  try {
    isLoading.value = true

    if (isPlaying.value) {
      voicePlayer.pause()
      isPlaying.value = false
    } else {
      await voicePlayer.play(props.voiceUrl)
      isPlaying.value = true
      updateProgress()
    }
  } catch (err: any) {
    error.value = '播放失败: ' + err.message
    canRetry.value = true
  } finally {
    isLoading.value = false
  }
}

const updateProgress = () => {
  if (!isPlaying.value) return

  currentTime.value = voicePlayer.getCurrentTime()

  if (currentTime.value < duration.value) {
    requestAnimationFrame(updateProgress)
  } else {
    isPlaying.value = false
    currentTime.value = 0
  }
}

const handleVolumeChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  const newVolume = parseInt(target.value) / 100
  volume.value = newVolume
  voicePlayer.setVolume(newVolume)
}

const toggleRecord = async () => {
  try {
    if (isRecording.value) {
      // 停止录音
      const recording = await voiceRecorder.stopRecording()
      previewRecording.value = recording
      isRecording.value = false
    } else {
      // 开始录音
      const hasPermission = await VoiceRecorder.requestPermission()
      if (!hasPermission) {
        throw new Error('无法获取麦克风权限')
      }

      await voiceRecorder.startRecording()
      isRecording.value = true
      recordingStartTime.value = Date.now()
      error.value = ''
      canRetry.value = false
    }
  } catch (err: any) {
    error.value = '录音失败: ' + err.message
    canRetry.value = true
    isRecording.value = false
  }
}

const cancelRecording = () => {
  voiceRecorder.cancelRecording()
  isRecording.value = false
  previewRecording.value = null
  error.value = ''
}

const playPreview = async () => {
  if (!previewRecording.value) return

  try {
    isLoading.value = true
    await voicePlayer.play(previewRecording.value.url)
  } catch (err: any) {
    error.value = '播放失败: ' + err.message
  } finally {
    isLoading.value = false
  }
}

const sendVoice = () => {
  if (previewRecording.value) {
    emit('voiceSend', previewRecording.value)
    previewRecording.value = null
  }
}

const deletePreview = () => {
  previewRecording.value = null
}

const retry = () => {
  error.value = ''
  canRetry.value = false
}

// 生命周期
onMounted(() => {
  if (props.autoplay && props.voiceUrl) {
    setTimeout(() => {
      togglePlay()
    }, 100)
  }

  // 设置音频时长
  if (props.duration > 0) {
    duration.value = props.duration
  }
})

onUnmounted(() => {
  voicePlayer.destroy()
  voiceRecorder.destroy()

  // 清理预览录音的URL
  if (previewRecording.value?.url) {
    URL.revokeObjectURL(previewRecording.value.url)
  }
})
</script>

<style lang="scss" scoped>
.voice-message {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 200px;
  max-width: 300px;
}

.voice-player,
.voice-recorder,
.voice-preview {
  background: #f8f9fa;
  border-radius: 12px;
  padding: 12px;
  border: 1px solid #e9ecef;
}

.voice-controls,
.recorder-controls,
.preview-controls {
  display: flex;
  align-items: center;
  gap: 12px;
}

.play-button,
.record-button {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: none;
  background: #007bff;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;

  &:hover {
    background: #0056b3;
    transform: scale(1.05);
  }

  &:disabled {
    background: #6c757d;
    cursor: not-allowed;
    transform: scale(1);
  }

  &.recording {
    background: #dc3545;
    animation: pulse 1.5s infinite;
  }
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.7; }
  100% { opacity: 1; }
}

.control-icon {
  width: 20px;
  height: 20px;
}

.voice-info,
.recorder-info,
.preview-info {
  flex: 1;
}

.voice-duration,
.preview-duration {
  font-weight: 500;
  color: #495057;
  margin-bottom: 4px;
}

.voice-progress {
  margin-top: 4px;
}

.progress-bar {
  width: 100%;
  height: 4px;
  background: #e9ecef;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 4px;
}

.progress-fill {
  height: 100%;
  background: #007bff;
  transition: width 0.1s linear;
}

.time-display {
  font-size: 12px;
  color: #6c757d;
}

.voice-volume {
  width: 60px;
}

.volume-slider {
  width: 100%;
  height: 4px;
  background: transparent;
  outline: none;
}

.recording-status {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #dc3545;
  font-weight: 500;
}

.recording-indicator {
  animation: pulse 1s infinite;
}

.recording-placeholder {
  color: #6c757d;
  font-style: italic;
}

.cancel-button {
  padding: 6px 12px;
  border: 1px solid #dc3545;
  background: white;
  color: #dc3545;
  border-radius: 6px;
  font-size: 12px;
  transition: all 0.2s;

  &:hover {
    background: #dc3545;
    color: white;
  }
}

.preview-actions {
  display: flex;
  gap: 8px;
}

.send-button,
.delete-button {
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  transition: all 0.2s;
}

.send-button {
  border: none;
  background: #28a745;
  color: white;

  &:hover {
    background: #218838;
  }
}

.delete-button {
  border: 1px solid #dc3545;
  background: white;
  color: #dc3545;

  &:hover {
    background: #dc3545;
    color: white;
  }
}

.voice-error {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: #f8d7da;
  border: 1px solid #f5c6cb;
  border-radius: 6px;
  color: #721c24;
  font-size: 14px;
}

.error-icon {
  font-size: 16px;
}

.retry-button {
  margin-left: auto;
  padding: 4px 8px;
  border: none;
  background: #721c24;
  color: white;
  border-radius: 4px;
  font-size: 12px;

  &:hover {
    background: #5a1518;
  }
}

.preview-size {
  font-size: 12px;
  color: #6c757d;
}
</style>