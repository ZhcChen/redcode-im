<template>
  <Teleport to="body">
    <Transition name="loading-mask">
      <div 
        v-if="visible" 
        class="loading-mask"
        @click.stop
        @touchmove.prevent
      >
        <div class="loading-container">
          <!-- 简化的加载动画 -->
          <div class="loading-spinner">
            <div class="spinner-dot"></div>
          </div>
          
          <!-- 自定义文字 -->
          <div class="loading-text" v-if="text">
            {{ text }}
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
interface Props {
  visible: boolean
  text?: string
}

withDefaults(defineProps<Props>(), {
  visible: false,
  text: '加载中...'
})
</script>

<style lang="scss" scoped>
.loading-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 9999;
  background-color: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(2px);
  display: flex;
  align-items: center;
  justify-content: center;
  user-select: none;
  cursor: wait;
}

.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 30px;
  background-color: rgba(255, 255, 255, 0.95);
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  min-width: 160px;
  text-align: center;
}

.loading-spinner {
  position: relative;
  width: 32px;
  height: 32px;
  margin-bottom: 16px;
}

.spinner-dot {
  position: absolute;
  width: 100%;
  height: 100%;
  border: 2px solid transparent;
  border-top-color: $primary-color;
  border-right-color: rgba($primary-color, 0.3);
  border-radius: 50%;
  animation: loading-spin 1s linear infinite;
}

.loading-text {
  font-size: 16px;
  font-weight: 500;
  color: $text-primary;
  line-height: 1.5;
  opacity: 0;
  animation: text-fade-in 0.5s ease-out 0.3s forwards;
}

@keyframes loading-spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

@keyframes text-fade-in {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

// 过渡动画
.loading-mask-enter-active {
  transition: all 0.3s ease-out;
}

.loading-mask-leave-active {
  transition: all 0.2s ease-in;
}

.loading-mask-enter-from {
  opacity: 0;
  backdrop-filter: blur(0px);
  
  .loading-container {
    transform: scale(0.8) translateY(20px);
    opacity: 0;
  }
}

.loading-mask-leave-to {
  opacity: 0;
  backdrop-filter: blur(0px);
  
  .loading-container {
    transform: scale(0.9) translateY(-10px);
    opacity: 0;
  }
}

// 深色主题适配
@media (prefers-color-scheme: dark) {
  .loading-mask {
    background-color: rgba(0, 0, 0, 0.8);
  }
  
  .loading-container {
    background-color: rgba(30, 30, 30, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.1);
  }
  
  .loading-text {
    color: $text-white;
  }
}

// 移动端适配
@media (max-width: 768px) {
  .loading-container {
    padding: 24px;
    min-width: 140px;
    margin: 20px;
  }
  
  .loading-spinner {
    width: 28px;
    height: 28px;
    margin-bottom: 12px;
  }
  
  .loading-text {
    font-size: 14px;
  }
}
</style>
