<template>
  <Dialog
    v-model="isVisible"
    title="举报群聊"
    @confirm="handleConfirm"
    @cancel="handleCancel"
    :confirm-text="isReporting ? '提交中...' : '提交举报'"
    :confirm-disabled="isReporting || !selectedReason || (selectedReason === 'other' && !customReason.trim())"
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
          :disabled="isReporting"
        ></textarea>
        <div class="char-count">{{ customReason.length }}/200</div>
      </div>

      <!-- 错误提示 -->
      <div v-if="errorMessage" class="error-message">
        {{ errorMessage }}
      </div>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import Dialog from './Dialog.vue'

interface Props {
  visible: boolean
}

interface Emits {
  (e: 'update:visible', value: boolean): void
  (e: 'confirm', reason: string): void
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  visible: false
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
const isReporting = ref(false)
const errorMessage = ref('')

// 选择举报原因
const handleSelectReason = (value: string) => {
  selectedReason.value = value
  errorMessage.value = ''

  // 如果不是"其他原因",清空自定义原因
  if (value !== 'other') {
    customReason.value = ''
  }
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

  // 构建举报原因文本
  let reason = ''
  if (selectedReason.value === 'other') {
    reason = customReason.value.trim()
  } else {
    const selectedItem = reportReasons.find(r => r.value === selectedReason.value)
    reason = selectedItem?.label || selectedReason.value
  }

  emit('confirm', reason)
  handleReset()
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
  isReporting.value = false
}

// 当对话框关闭时重置状态
watch(() => props.visible, (newVal) => {
  if (!newVal) {
    handleReset()
  }
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

.error-message {
  padding: 8px 12px;
  background-color: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
  color: #dc2626;
  font-size: 14px;
}
</style>
