<template>
  <textarea
    v-if="multiline"
    v-model="localValue"
    class="dialog-input dialog-input--textarea"
    autocapitalize="none"
    autocorrect="off"
    autocomplete="off"
    spellcheck="false"
    :rows="rows"
    v-bind="$attrs"
    @input="handleInput"
    @blur="handleBlur"
    @focus="handleFocus"
  />
  <input
    v-else
    v-model="localValue"
    class="dialog-input"
    autocapitalize="none"
    autocorrect="off"
    autocomplete="off"
    spellcheck="false"
    v-bind="$attrs"
    @input="handleInput"
    @blur="handleBlur"
    @focus="handleFocus"
  />
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

interface Props {
  /** 输入框的值 */
  modelValue?: string
  /** 多行模式 */
  multiline?: boolean
  /** 多行时的行数 */
  rows?: number
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  multiline: false,
  rows: 3
})

const emits = defineEmits<{
  'update:modelValue': [value: string]
  'blur': [event: Event]
  'focus': [event: Event]
}>()

const localValue = ref(props.modelValue)

// 监听 props 变化
watch(() => props.modelValue, (newValue) => {
  localValue.value = newValue || ''
})

// 监听本地值变化
watch(localValue, (newValue) => {
  emits('update:modelValue', newValue)
})

// 处理输入事件
const handleInput = (event: Event) => {
  const target = event.target as HTMLInputElement | HTMLTextAreaElement
  localValue.value = target.value
}

// 处理失焦事件
const handleBlur = (event: Event) => {
  emits('blur', event)
}

// 处理聚焦事件
const handleFocus = (event: Event) => {
  emits('focus', event)
}
</script>

<style scoped lang="scss">
.dialog-input {
  width: 100%;
  background: #FFFFFF;
  border: 1px solid #00C2B31A;
  border-radius: 22px;
  padding: 0 16px;
  font-size: 12px;
  color: #999999;
  outline: none;
  transition: all 0.3s ease;
  box-sizing: border-box;
  
  &::placeholder {
    color: #999999;
    font-size: 12px;
  }
  
  &:focus {
    border-color: rgba(0, 194, 179, 0.3);
    box-shadow: 0 0 0 2px rgba(0, 194, 179, 0.1);
  }
}

.dialog-input--textarea {
  min-height: 88px;
  padding: 12px 16px;
  border-radius: 12px;
  line-height: 1.5;
  resize: vertical;
}
</style>
