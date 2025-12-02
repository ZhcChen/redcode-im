<template>
  <Teleport to="body">
    <Transition name="dialog-fade">
      <div v-if="visible" class="dialog-overlay" @click="handleOverlayClick">
        <Transition name="dialog-scale">
          <div 
            v-if="visible" 
            :class="['dialog-container', { 'dialog-no-select': disableTextSelection }]" 
            @click.stop
          >
            <div class="dialog-header">
              <h3 class="dialog-title">{{ title }}</h3>
              <button class="dialog-close-btn" @click="handleClose">
                <img src="@/assets/image/icon-close.svg" alt="关闭" />
              </button>
            </div>
            <ScrollContainer class="dialog-content">
              <slot></slot>
            </ScrollContainer>
            <div v-if="showFooter" class="dialog-footer">
              <button class="dialog-btn dialog-btn-cancel" @click="handleCancel">
                {{ cancelText }}
              </button>
              <button 
                class="dialog-btn dialog-btn-confirm" 
                :disabled="confirmDisabled"
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
import ScrollContainer from './ScrollContainer.vue'

interface Props {
  /** 弹窗标题 */
  title?: string
  /** 是否显示弹窗（v-model） */
  modelValue?: boolean
  /** 是否显示弹窗（替代 modelValue） */
  visible?: boolean
  /** 是否可以通过点击蒙版关闭弹窗 */
  closeOnOverlay?: boolean
  /** 是否显示底部按钮 */
  showFooter?: boolean
  /** 确认按钮文本 */
  confirmText?: string
  /** 取消按钮文本 */
  cancelText?: string
  /** 确认按钮是否禁用 */
  confirmDisabled?: boolean
  /** 是否禁用弹窗内文本选中（表单控件除外） */
  disableTextSelection?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  title: '提示',
  closeOnOverlay: true,
  showFooter: true,
  confirmText: '确定',
  cancelText: '取消',
  confirmDisabled: false,
  disableTextSelection: false
})

const emits = defineEmits<{
  'update:modelValue': [value: boolean]
  'close': []
  'cancel': []
  'confirm': []
}>()

// 获取实际可见性值（优先使用 modelValue，如果没有则使用 visible）
const getActualVisible = () => {
  if (props.modelValue !== undefined) {
    return props.modelValue
  }
  return props.visible ?? false
}

const visible = ref(getActualVisible())

// 监听 modelValue 变化
watch(() => props.modelValue, (newValue) => {
  if (newValue !== undefined) {
    visible.value = newValue
  }
})

// 监听 visible 变化
watch(() => props.visible, (newValue) => {
  if (newValue !== undefined) {
    visible.value = newValue
  }
})

// 监听 visible 变化，同步到父组件
watch(visible, (newValue) => {
  // 只有当原始 prop 是 modelValue 时才发射 update 事件
  if (props.modelValue !== undefined) {
    emits('update:modelValue', newValue)
  }
})

// 处理蒙版点击
const handleOverlayClick = () => {
  if (props.closeOnOverlay) {
    handleClose()
  }
}

// 处理关闭
const handleClose = () => {
  visible.value = false
  emits('close')
}

// 处理取消
const handleCancel = () => {
  emits('cancel')
  handleClose()
}

// 处理确定
const handleConfirm = () => {
  emits('confirm')
}

// 暴露方法给父组件
defineExpose({
  close: handleClose
})
</script>

<style scoped lang="scss">
.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 9999;
  @include flex-center;
}

.dialog-container {
  background: linear-gradient(to bottom, #E7FFF7, #FFFFFF);
  border-radius: 16px;
  padding: 20px 24px;
  max-width: 90vw;
  max-height: 90vh;
  min-width: 320px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.dialog-header {
  @include flex-between;
  margin-bottom: 16px;
  flex-shrink: 0;
}

.dialog-title {
  font-size: 18px;
  font-weight: 600;
  color: $text-primary;
  margin: 0;
  line-height: 1.4;
}

.dialog-close-btn {
  @include button-reset;
  width: 24px;
  height: 24px;
  @include flex-center;
  border-radius: 4px;
  transition: all 0.2s ease;
  
  &:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  
  &:active {
    transform: scale(0.95);
  }
  
  img {
    width: 24px;
    height: 24px;
    display: block;
  }
}

.dialog-content {
  flex: 1;

  // 自定义滚动条样式
  &::-webkit-scrollbar {
    width: 8px;
  }

  &::-webkit-scrollbar-track {
    background: rgba(0, 0, 0, 0.1);
    border-radius: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.3);
    border-radius: 4px;

    &:hover {
      background: rgba(0, 0, 0, 0.5);
    }
  }
}

.dialog-no-select {
  .dialog-title {
    user-select: none;
    cursor: default;
  }

  .dialog-content {
    user-select: none;
    cursor: default;
  }

  .dialog-content input,
  .dialog-content textarea,
  .dialog-content select {
    user-select: text;
    cursor: text;
  }

  .dialog-btn,
  .dialog-content button,
  .dialog-content [role='button'] {
    cursor: pointer;
    user-select: none;
  }
}

// 动画效果
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
  transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.dialog-scale-enter-from {
  opacity: 0;
  transform: scale(0.8) translateY(-20px);
}

.dialog-scale-leave-to {
  opacity: 0;
  transform: scale(0.9) translateY(10px);
}

.dialog-scale-enter-to,
.dialog-scale-leave-from {
  opacity: 1;
  transform: scale(1) translateY(0);
}

// 底部按钮区域
.dialog-footer {
  @include flex-between;
  margin-top: 24px;
  flex-shrink: 0;
  gap: 16px;
}

// 按钮基础样式
.dialog-btn {
  @include button-reset;
  width: 120px;
  height: 40px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: $font-weight-medium;
  transition: all $transition-base;
  @include flex-center;
  
  &:active {
    transform: scale(0.98);
  }
}

// 取消按钮样式
.dialog-btn-cancel {
  background: transparent;
  border: 1px solid $primary-color;
  color: $primary-color;
  
  &:hover:not(:disabled) {
    background: rgba($primary-color, 0.05);
    border-color: $primary-dark;
    color: $primary-dark;
  }
}

// 确定按钮样式
.dialog-btn-confirm {
  background: $primary-color;
  border: 1px solid $primary-color;
  color: $text-white;
  
  &:hover:not(:disabled) {
    background: $primary-dark;
    border-color: $primary-dark;
  }
  
  &:disabled {
    background: #d9d9d9;
    border-color: #d9d9d9;
    color: #999999;
    cursor: not-allowed;
    
    &:active {
      transform: none;
    }
  }
}

// 响应式设计
@media (max-width: 640px) {
  .dialog-container {
    margin: 20px;
    min-width: auto;
    max-width: calc(100vw - 40px);
  }
  
  .dialog-footer {
    margin-top: 20px;
    gap: 12px;
  }
  
  .dialog-btn {
    width: 100px;
    height: 36px;
    font-size: 12px;
  }
}
</style>
