<script setup lang="ts">
import { ref, computed } from 'vue'

// defineProps 和 withDefaults 现在是编译器宏，无需导入
const props = withDefaults(defineProps<{
  type: string,
  placeholder: string,
  modelValue?: string
}>(), {
  type: 'text',
  placeholder: '请输入',
  modelValue: ''
})

// 定义 emit 事件
const emit = defineEmits(['update:modelValue', 'keydown', 'keyup', 'keypress'])

// 密码可见性状态
const showPassword = ref(false)

// 计算实际的输入框类型
const actualType = computed(() => {
  if (props.type === 'password') {
    return showPassword.value ? 'text' : 'password'
  }
  return props.type
})

// 是否显示密码切换按钮
const showPasswordToggle = computed(() => {
  return props.type === 'password' && props.modelValue && props.modelValue.length > 0
})

// 处理输入事件
function handleInput(event: Event) {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
}

// 切换密码可见性
function togglePasswordVisibility() {
  showPassword.value = !showPassword.value
}

// 处理键盘事件
function handleKeydown(event: KeyboardEvent) {
  emit('keydown', event)
}

function handleKeyup(event: KeyboardEvent) {
  emit('keyup', event)
}

function handleKeypress(event: KeyboardEvent) {
  emit('keypress', event)
}
</script>

<template>
  <div class="b-input">
    <div class="b-input-prefix"></div>
    <input 
      :type="actualType" 
      :placeholder="placeholder" 
      :value="modelValue"
      @input="handleInput"
      @keydown="handleKeydown"
      @keyup="handleKeyup"
      @keypress="handleKeypress"
    >
    <div 
      v-if="showPasswordToggle" 
      class="b-input-suffix"
      @click="togglePasswordVisibility"
    >
      <img 
        src="@/assets/image/icon-passwd-show.svg" 
        alt="切换密码可见性"
        :class="{ 'password-hidden': !showPassword }"
      >
    </div>
  </div>
</template>

<style lang="scss" scoped>
  .b-input {
    background: rgba(243, 247, 248, 1);
    height: 44px;
    width: 100%;
    border-radius: 22px;
    box-sizing: border-box;
    padding: 0 20px;
    display: flex;
    justify-content: flex-start;
    align-items: center;
    position: relative;

    &-prefix {

    }

    &-suffix {
      margin-left: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      
      img {
        width: 16px;
        height: 16px;
        transition: opacity 0.2s ease;
        
        &.password-hidden {
          opacity: 0.6;
        }
      }
      
      &:hover img {
        opacity: 0.8;
      }
    }

    input {
      flex: 1;
      font-size: 14px;
      background: none;
      border: none;
      outline: none;
      color: inherit;
      font-family: inherit;
      
      &::placeholder {
        color: rgba(0, 0, 0, 0.4);
      }
    }
  }
</style>
