<template>
  <Teleport to="body">
    <Transition name="dialog-fade">
      <div v-if="visible" class="confirm-dialog-overlay" @click="handleOverlayClick">
        <Transition name="dialog-scale">
          <div v-if="visible" class="confirm-dialog-container" @click.stop>
            <div class="confirm-dialog-header">
              <h3 class="confirm-dialog-title">{{ title }}</h3>
            </div>
            <div class="confirm-dialog-content">
              <div class="confirm-message">{{ message }}</div>
              <div v-if="description" class="confirm-description">{{ description }}</div>
            </div>
            <div class="confirm-dialog-footer">
              <button class="confirm-btn confirm-btn-cancel" @click="handleCancel">
                {{ cancelText }}
              </button>
              <button 
                class="confirm-btn confirm-btn-confirm" 
                :class="{ danger: type === 'danger' }"
                @click="handleConfirm"
              >
                {{ confirmText }}
              </button>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

interface Props {
  visible: boolean
  title?: string
  message: string
  description?: string
  confirmText?: string
  cancelText?: string
  type?: 'normal' | 'danger'
  closeOnOverlay?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  title: '确认',
  confirmText: '确定',
  cancelText: '取消',
  type: 'normal',
  closeOnOverlay: true
})

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()

const handleOverlayClick = () => {
  if (props.closeOnOverlay) {
    handleCancel()
  }
}

const handleConfirm = () => {
  emit('confirm')
  emit('update:visible', false)
}

const handleCancel = () => {
  emit('cancel')
  emit('update:visible', false)
}
</script>

<style scoped lang="scss">
.confirm-dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10001;
}

.confirm-dialog-container {
  background: #ffffff;
  border-radius: 12px;
  width: 420px;
  max-width: 90vw;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  overflow: hidden;
}

.confirm-dialog-header {
  padding: 20px 24px 16px;
  border-bottom: 1px solid #f0f0f0;
}

.confirm-dialog-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #1f1f1f;
}

.confirm-dialog-content {
  padding: 24px;
}

.confirm-message {
  font-size: 15px;
  color: #333;
  line-height: 1.6;
  margin-bottom: 8px;
}

.confirm-description {
  font-size: 13px;
  color: #666;
  line-height: 1.5;
  margin-top: 12px;
  padding: 12px;
  background-color: #f7f7f7;
  border-radius: 6px;
  border-left: 3px solid #ff9500;
}

.confirm-dialog-footer {
  padding: 16px 24px;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  border-top: 1px solid #f0f0f0;
  background-color: #fafafa;
}

.confirm-btn {
  padding: 10px 24px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s;
  min-width: 80px;

  &:active {
    transform: scale(0.98);
  }
}

.confirm-btn-cancel {
  background-color: #ffffff;
  color: #666;
  border: 1px solid #d9d9d9;

  &:hover {
    background-color: #f5f5f5;
    border-color: #b8b8b8;
  }
}

.confirm-btn-confirm {
  background-color: #1890ff;
  color: #ffffff;

  &:hover {
    background-color: #40a9ff;
  }

  &.danger {
    background-color: #ff4d4f;

    &:hover {
      background-color: #ff7875;
    }
  }
}

// 过渡动画
.dialog-fade-enter-active,
.dialog-fade-leave-active {
  transition: opacity 0.3s ease;
}

.dialog-fade-enter-from,
.dialog-fade-leave-to {
  opacity: 0;
}

.dialog-scale-enter-active,
.dialog-scale-leave-active {
  transition: all 0.3s ease;
}

.dialog-scale-enter-from,
.dialog-scale-leave-to {
  opacity: 0;
  transform: scale(0.9);
}
</style>
