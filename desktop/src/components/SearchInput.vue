<template>
  <div class="search-input">
    <input
      v-model="inputValue"
      type="text"
      :placeholder="placeholder"
      class="search-field"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
      @keyup.enter="onEnter"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

// Props
interface Props {
  modelValue?: string
  placeholder?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  placeholder: '搜索...'
})

// Emits
const emit = defineEmits(['update:modelValue', 'search', 'focus', 'blur'])

// 内部状态
const inputValue = ref(props.modelValue)

// 监听外部值变化
watch(() => props.modelValue, (newValue) => {
  inputValue.value = newValue || ''
})

// 事件处理
const onInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  inputValue.value = target.value
  emit('update:modelValue', target.value)
}

const onFocus = (event: FocusEvent) => {
  emit('focus', event)
}

const onBlur = (event: FocusEvent) => {
  emit('blur', event)
}

const onEnter = () => {
  emit('search', inputValue.value || '')
}
</script>

<style lang="scss" scoped>
.search-input {
  width: 100%;
  height: 40px;
  background-color: #ffffff;
  border-radius: 20px; // 高度的一半
  border: 1px solid #e0e0e0;
  outline: none;
  box-sizing: border-box;
  
  .search-field {
    width: 100%;
    height: 100%;
    border: none;
    outline: none;
    background: transparent;
    font-size: 16px;
    line-height: 20px;
    color: $chat-message-color; // #707991
    font-family: inherit;
    padding: 0 16px;
    border-radius: 20px;
    box-sizing: border-box;
    
    &::placeholder {
      color: $chat-message-color;
      opacity: 0.6;
    }
    
    // 移除输入框的默认样式
    &:focus {
      outline: none;
    }
    
    // 移除 autofill 的默认样式
    &:-webkit-autofill,
    &:-webkit-autofill:hover,
    &:-webkit-autofill:focus {
      -webkit-box-shadow: 0 0 0 1000px $bg-light-gray inset;
      -webkit-text-fill-color: $chat-message-color;
      border: none;
    }
  }
}
</style>
