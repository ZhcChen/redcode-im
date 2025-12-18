<template>
  <Dialog
    v-model="isVisible"
    :title="title"
    @confirm="handleConfirm"
    @cancel="handleCancel"
    :confirm-text="submitting ? '提交中...' : '提交举报'"
    :confirm-disabled="submitting || !selectedReason || (selectedReason === 'other' && !customReason.trim()) || attachments.length === 0"
  >
    <div class="report-content">
      <!-- 警告提示 -->
      <div class="report-warning">
        <div class="warning-icon">⚠️</div>
        <div class="warning-text">
          恶意举报将受到处罚，请谨慎操作
        </div>
      </div>

      <!-- 举报原因选择 -->
      <div class="report-section">
        <div class="section-title">请选择举报原因</div>
        <div class="reason-list">
          <div
            v-for="reason in reportReasons"
            :key="reason.value"
            class="reason-item"
            :class="{ 'reason-item--selected': selectedReason === reason.value }"
            @click="handleSelectReason(reason.value)"
          >
            <div class="reason-radio">
              <div v-if="selectedReason === reason.value" class="reason-radio-inner"></div>
            </div>
            <div class="reason-label">{{ reason.label }}</div>
          </div>
        </div>
      </div>

      <!-- 自定义原因输入 -->
      <div v-if="selectedReason === 'other'" class="report-section">
        <div class="section-title">请详细说明举报原因</div>
        <textarea
          v-model="customReason"
          class="custom-reason-input"
          placeholder="请详细描述您的举报原因..."
          maxlength="200"
          rows="4"
          :disabled="submitting"
        ></textarea>
        <div class="char-count">{{ customReason.length }}/200</div>
      </div>

      <!-- 截图（必填） -->
      <div class="report-section">
        <div class="section-title">请上传截图（必填）</div>
        <div class="attachment-actions">
          <button
            type="button"
            class="attachment-add-btn"
            :disabled="submitting || attachments.length >= maxAttachments"
            @click="handlePickAttachments"
          >
            选择截图
          </button>
          <div class="attachment-hint">
            已选择 {{ attachments.length }}/{{ maxAttachments }} 张
          </div>
        </div>

        <div v-if="attachments.length" class="attachment-grid">
          <div
            v-for="(item, index) in attachments"
            :key="item.url"
            class="attachment-item"
          >
            <img class="attachment-thumb" :src="item.url" alt="截图预览" />
            <button
              type="button"
              class="attachment-remove-btn"
              :disabled="submitting"
              @click="removeAttachment(index)"
            >
              ×
            </button>
          </div>
        </div>
      </div>

      <!-- 错误提示 -->
      <div v-if="errorMessage" class="error-message">
        {{ errorMessage }}
      </div>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import Dialog from './Dialog.vue'

interface Props {
  visible: boolean
  title?: string
  submitting?: boolean
  maxAttachments?: number
}

interface Emits {
  (e: 'update:visible', value: boolean): void
  (e: 'confirm', payload: { content: string; attachments: File[] }): void
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  title: '举报',
  submitting: false,
  maxAttachments: 3
})

const emit = defineEmits<Emits>()

// 内部可见性状态
const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

// 举报原因列表
const reportReasons = [
  { value: 'illegal', label: '存在违法违规内容' },
  { value: 'porn', label: '色情低俗内容' },
  { value: 'fraud', label: '欺诈骗钱' },
  { value: 'harassment', label: '骚扰他人' },
  { value: 'spam', label: '垃圾广告' },
  { value: 'other', label: '其他原因' }
]

// 状态
const selectedReason = ref<string>('')
const customReason = ref('')
const errorMessage = ref('')

type AttachmentPreview = {
  file: File
  url: string
}

const attachments = ref<AttachmentPreview[]>([])

const maxAttachments = computed(() => Math.max(1, props.maxAttachments || 1))

// 选择举报原因
const handleSelectReason = (value: string) => {
  selectedReason.value = value
  errorMessage.value = ''

  // 如果不是"其他原因",清空自定义原因
  if (value !== 'other') {
    customReason.value = ''
  }
}

const handlePickAttachments = () => {
  if (props.submitting) return
  if (attachments.value.length >= maxAttachments.value) return

  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*'
  input.multiple = true
  input.style.display = 'none'

  document.body.appendChild(input)

  const cleanup = () => {
    if (input.parentNode) {
      document.body.removeChild(input)
    }
  }

  input.addEventListener(
    'change',
    () => {
      const files = input.files ? Array.from(input.files) : []
      addAttachments(files)
      cleanup()
    },
    { once: true }
  )

  input.addEventListener(
    'cancel',
    () => {
      cleanup()
    },
    { once: true }
  )

  input.click()
}

const addAttachments = (files: File[]) => {
  if (!files.length) return

  const remaining = maxAttachments.value - attachments.value.length
  const candidateFiles = files.slice(0, remaining)

  for (const file of candidateFiles) {
    if (!file || typeof file.type !== 'string' || !file.type.startsWith('image/')) {
      continue
    }
    const url = URL.createObjectURL(file)
    attachments.value.push({ file, url })
  }

  errorMessage.value = ''
}

const removeAttachment = (index: number) => {
  const item = attachments.value[index]
  if (!item) return
  try {
    URL.revokeObjectURL(item.url)
  } catch (_) {
    // ignore
  }
  attachments.value.splice(index, 1)
}

// 确认举报
const handleConfirm = () => {
  // 验证
  if (!selectedReason.value) {
    errorMessage.value = '请选择举报原因'
    return
  }

  if (selectedReason.value === 'other' && !customReason.value.trim()) {
    errorMessage.value = '请输入举报原因'
    return
  }

  if (!attachments.value.length) {
    errorMessage.value = '请至少上传 1 张截图'
    return
  }

  // 构建举报原因文本
  let reason = ''
  if (selectedReason.value === 'other') {
    reason = customReason.value.trim()
  } else {
    const selectedItem = reportReasons.find(r => r.value === selectedReason.value)
    reason = selectedItem?.label || selectedReason.value
  }

  emit('confirm', {
    content: reason,
    attachments: attachments.value.map((item) => item.file)
  })
}

// 取消
const handleCancel = () => {
  emit('close')
  handleReset()
}

// 重置状态
const handleReset = () => {
  selectedReason.value = ''
  customReason.value = ''
  errorMessage.value = ''

  // 清理截图预览 URL
  for (const item of attachments.value) {
    try {
      URL.revokeObjectURL(item.url)
    } catch (_) {
      // ignore
    }
  }
  attachments.value = []
}

// 当对话框关闭时重置状态
watch(() => props.visible, (newVal) => {
  if (!newVal) {
    handleReset()
  }
})

onBeforeUnmount(() => {
  handleReset()
})
</script>

<style lang="scss" scoped>
.report-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 16px 8px;
}

.report-warning {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background-color: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 8px;

  .warning-icon {
    font-size: 20px;
    flex-shrink: 0;
  }

  .warning-text {
    font-size: 14px;
    color: #856404;
    line-height: 1.4;
  }
}

.report-section {
  display: flex;
  flex-direction: column;
  gap: 12px;

  .section-title {
    font-size: 14px;
    font-weight: 500;
    color: #2C2D3A;
  }
}

.reason-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.reason-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background-color: #f5f5f5;
  border-radius: 8px;
  transition: all 0.2s;

  &:hover {
    background-color: #e8e8e8;
  }

  &--selected {
    background-color: #e3f2fd;
    border: 1px solid #2196f3;

    .reason-label {
      color: #1976d2;
      font-weight: 500;
    }
  }

  .reason-radio {
    width: 18px;
    height: 18px;
    border: 2px solid #ccc;
    border-radius: 50%;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: border-color 0.2s;
  }

  &--selected .reason-radio {
    border-color: #2196f3;
  }

  .reason-radio-inner {
    width: 10px;
    height: 10px;
    background-color: #2196f3;
    border-radius: 50%;
  }

  .reason-label {
    font-size: 14px;
    color: #2C2D3A;
    flex: 1;
  }
}

.custom-reason-input {
  width: 100%;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 14px;
  color: #2C2D3A;
  resize: none;
  outline: none;
  transition: border-color 0.2s;
  font-family: inherit;
  box-sizing: border-box;

  &:focus {
    border-color: #2196f3;
  }

  &::placeholder {
    color: #999;
  }

  &:disabled {
    background-color: #f5f5f5;
    cursor: not-allowed;
  }
}

.char-count {
  text-align: right;
  font-size: 12px;
  color: #999;
}

.attachment-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.attachment-add-btn {
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  background: #fff;
  color: #2C2D3A;
  cursor: pointer;
  font-size: 14px;

  &:disabled {
    background-color: #f5f5f5;
    cursor: not-allowed;
    color: #999;
  }
}

.attachment-hint {
  font-size: 12px;
  color: #999;
}

.attachment-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.attachment-item {
  position: relative;
  width: 100%;
  padding-top: 100%;
  border-radius: 8px;
  overflow: hidden;
  background: #f5f5f5;
  border: 1px solid #e5e5e5;
}

.attachment-thumb {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.attachment-remove-btn {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: none;
  background: rgba(0, 0, 0, 0.6);
  color: #fff;
  cursor: pointer;
  line-height: 22px;
  text-align: center;
  font-size: 16px;

  &:disabled {
    cursor: not-allowed;
    opacity: 0.6;
  }
}

.error-message {
  padding: 8px 12px;
  background-color: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
  color: #dc2626;
  font-size: 14px;
}
</style>
