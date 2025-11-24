<template>
  <div class="popover-container" ref="containerRef">
    <!-- 触发器内容 -->
    <div 
      class="popover-trigger"
      @click="togglePopover"
      ref="triggerRef"
    >
      <slot name="trigger"></slot>
    </div>
    
    <!-- 弹窗内容 -->
    <Teleport to="body">
      <div 
        v-if="visible" 
        class="popover-overlay"
        :style="popoverStyle"
        ref="popoverRef"
      >
        <!-- 箭头指示器 -->
        <div class="popover-arrow" :style="arrowStyle" :data-placement="placement"></div>
        <!-- 主内容节点 -->
        <div class="popover-content" @click="handleContentClick">
          <slot name="content"></slot>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'

interface Props {
  placement?: 'top' | 'bottom' | 'left' | 'right'
  trigger?: 'click' | 'hover'
  offset?: number
  // 主内容偏移
  contentOffsetX?: number
  contentOffsetY?: number
  // 指示标偏移
  arrowOffsetX?: number
  arrowOffsetY?: number
}

const props = withDefaults(defineProps<Props>(), {
  placement: 'right',
  trigger: 'click',
  offset: 8,
  contentOffsetX: 0,
  contentOffsetY: 0,
  arrowOffsetX: 0,
  arrowOffsetY: 0
})

const visible = ref(false)
const containerRef = ref<HTMLElement>()
const triggerRef = ref<HTMLElement>()
const popoverRef = ref<HTMLElement>()

// 切换弹窗显示状态
const togglePopover = (event: Event) => {
  if (props.trigger === 'click') {
    event.stopPropagation()
    visible.value = !visible.value
    if (visible.value) {
      nextTick(() => {
        updatePosition()
      })
    }
  }
}

// 弹窗位置计算
const popoverStyle = ref({})
const arrowStyle = ref({})

const updatePosition = () => {
  if (!triggerRef.value || !popoverRef.value) return

  const triggerRect = triggerRef.value.getBoundingClientRect()
  const popoverRect = popoverRef.value.getBoundingClientRect()
  
  // 如果弹窗还没有渲染完成，等待下一帧再计算
  if (popoverRect.width === 0 || popoverRect.height === 0) {
    requestAnimationFrame(updatePosition)
    return
  }
  
  let top = 0
  let left = 0
  let arrowTop = '50%'
  let arrowLeft = '50%'
  let arrowTransform = ''

  switch (props.placement) {
    case 'right':
      top = triggerRect.top + triggerRect.height / 2 - popoverRect.height / 2
      left = triggerRect.right + (props.offset || 8)
      arrowTop = '50%'
      arrowLeft = '-6px'
      arrowTransform = 'translateY(-50%) rotate(45deg)'
      break
    case 'left':
      top = triggerRect.top + triggerRect.height / 2 - popoverRect.height / 2
      left = triggerRect.left - popoverRect.width - (props.offset || 8)
      arrowTop = '50%'
      arrowLeft = 'calc(100% - 6px)'
      arrowTransform = 'translateY(-50%) rotate(45deg)'
      break
    case 'top':
      top = triggerRect.top - popoverRect.height - (props.offset || 8)
      left = triggerRect.left + triggerRect.width / 2 - popoverRect.width / 2
      arrowTop = 'calc(100% - 6px)'
      // 针对宽触发器的箭头位置微调，让箭头更贴近视觉中心
      const triggerCenter = triggerRect.width / 2
      const popoverCenter = popoverRect.width / 2
      if (triggerRect.width > 80) { // 如果触发器较宽（如SideMenu中的菜单项）
        arrowLeft = `${triggerCenter}px` // 箭头对齐到触发器的中心位置
      } else {
        arrowLeft = '50%' // 默认居中
      }
      arrowTransform = 'translateX(-50%) rotate(45deg)'
      break
    case 'bottom':
      top = triggerRect.bottom + (props.offset || 8)
      left = triggerRect.left + triggerRect.width / 2 - popoverRect.width / 2
      arrowTop = '-6px'
      arrowLeft = '50%'
      arrowTransform = 'translateX(-50%) rotate(45deg)'
      break
  }

  // 应用主内容偏移
  left += (props.contentOffsetX || 0)
  top += (props.contentOffsetY || 0)

  // 确保弹窗不会超出视窗边界
  const viewportWidth = window.innerWidth
  const viewportHeight = window.innerHeight

  if (left < 8) left = 8
  if (left + popoverRect.width > viewportWidth - 8) left = viewportWidth - popoverRect.width - 8
  if (top < 8) top = 8
  if (top + popoverRect.height > viewportHeight - 8) top = viewportHeight - popoverRect.height - 8

  popoverStyle.value = {
    position: 'fixed',
    top: `${top}px`,
    left: `${left}px`,
    zIndex: 9999
  }

  // 应用指示标偏移
  let finalArrowLeft = arrowLeft
  let finalArrowTop = arrowTop
  
  // 处理指示标偏移，需要考虑不同的placement
  if (props.placement === 'top' || props.placement === 'bottom') {
    // 上下placement时，指示标可以左右偏移
    if (typeof arrowLeft === 'string' && arrowLeft.includes('%')) {
      finalArrowLeft = `calc(${arrowLeft} + ${props.arrowOffsetX || 0}px)`
    } else if (typeof arrowLeft === 'string' && arrowLeft.includes('px')) {
      const currentOffset = parseFloat(arrowLeft)
      finalArrowLeft = `${currentOffset + (props.arrowOffsetX || 0)}px`
    }
    // 上下偏移对于top/bottom placement不太适用，但仍然应用
    if (typeof arrowTop === 'string' && arrowTop.includes('px')) {
      const currentOffset = parseFloat(arrowTop.replace('calc(100% - ', '').replace('px)', ''))
      if (props.placement === 'top') {
        finalArrowTop = `calc(100% - ${currentOffset + (props.arrowOffsetY || 0)}px)`
      } else {
        finalArrowTop = `${currentOffset + (props.arrowOffsetY || 0)}px`
      }
    }
  } else {
    // 左右placement时，指示标可以上下偏移
    if (typeof arrowTop === 'string' && arrowTop.includes('%')) {
      finalArrowTop = `calc(${arrowTop} + ${props.arrowOffsetY || 0}px)`
    }
    // 左右偏移
    if (typeof arrowLeft === 'string' && arrowLeft.includes('px')) {
      const currentOffset = parseFloat(arrowLeft.replace('calc(100% - ', '').replace('px)', ''))
      if (props.placement === 'left') {
        finalArrowLeft = `calc(100% - ${currentOffset - (props.arrowOffsetX || 0)}px)`
      } else {
        finalArrowLeft = `${currentOffset + (props.arrowOffsetX || 0)}px`
      }
    }
  }

  arrowStyle.value = {
    position: 'absolute',
    top: finalArrowTop,
    left: finalArrowLeft,
    transform: arrowTransform
  }
}

// 点击外部关闭弹窗
const handleClickOutside = (event: Event) => {
  const target = event.target as Node
  if (containerRef.value && !containerRef.value.contains(target) && 
      popoverRef.value && !popoverRef.value.contains(target)) {
    visible.value = false
  }
}

// 处理弹窗内容点击事件
const handleContentClick = (event: Event) => {
  // 允许内容区域的点击事件正常冒泡，但延迟关闭弹窗
  // 这样可以确保点击事件处理器有足够时间执行
  setTimeout(() => {
    visible.value = false
  }, 100)
}

// 暴露方法给父组件
const show = () => {
  visible.value = true
  nextTick(() => {
    updatePosition()
  })
}

const hide = () => {
  visible.value = false
}

defineExpose({
  show,
  hide,
  visible
})

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
  window.addEventListener('resize', updatePosition)
  window.addEventListener('scroll', updatePosition)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
  window.removeEventListener('resize', updatePosition)
  window.removeEventListener('scroll', updatePosition)
})
</script>

<style lang="scss" scoped>
.popover-container {
  display: inline-block;
}

.popover-trigger {
  display: inline-block;
}

// 整体阴影效果，应用到整个弹窗容器
.popover-overlay {
  position: fixed;
  z-index: 9999;
  filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.15));
}

.popover-content {
  background: white;
  border-radius: 8px;
  padding: 8px 0;
  min-width: 120px;
  position: relative;
  z-index: 1;
}

.popover-arrow {
  width: 12px;
  height: 12px;
  background: white;
  position: absolute;
  z-index: 2;
  
  // 根据不同方向只对可见的角设置圆角
  &[data-placement="top"] {
    border-radius: 0 0 4px 0; // 只有右下角圆角
  }
  
  &[data-placement="bottom"] {
    border-radius: 4px 0 0 0; // 只有左上角圆角
  }
  
  &[data-placement="left"] {
    border-radius: 0 4px 0 0; // 只有右上角圆角
  }
  
  &[data-placement="right"] {
    border-radius: 0 0 0 4px; // 只有左下角圆角
  }
}
</style>
