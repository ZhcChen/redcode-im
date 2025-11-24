<template>
  <div class="b-tabs" :class="customClass" ref="tabsContainer">
    <div
      v-for="(tab, index) in tabs"
      :key="index"
      :ref="el => setTabItemRef(el, index)"
      class="b-tabs-item"
      :class="{ 
        active: modelValue === tab.value,
        disabled: tab.disabled
      }"
      @click="handleTabClick(tab.value, tab.disabled)"
    >
      {{ tab.label }}
    </div>
    <div
      class="b-tabs-slider"
      :style="sliderStyle"
    ></div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted, watch, nextTick } from 'vue';

export interface TabItem {
  label: string;
  value: string | number;
  disabled?: boolean;
}

interface Props {
  tabs: TabItem[];
  modelValue: string | number;
  customClass?: string;
  gap?: number;
  fontSize?: number;
  marginBottom?: number;
}

const props = withDefaults(defineProps<Props>(), {
  customClass: '',
  gap: 32,
  fontSize: 14,
  marginBottom: 56
});

const emits = defineEmits<{
  'update:modelValue': [value: string | number];
  'change': [value: string | number];
}>();

const tabsContainer = ref<HTMLElement | null>(null);
const tabItems = ref<(HTMLElement | null)[]>([]);
const forceUpdate = ref(0); // 用于强制重新计算位置

// 设置 tab item 的 ref
function setTabItemRef(el: HTMLElement | null, index: number) {
  if (el) {
    tabItems.value[index] = el;
  }
}

// 更新滑动条位置
function updateSliderPosition() {
  forceUpdate.value++;
}

// 计算滑动条位置 - 使用实际DOM元素位置
const sliderStyle = computed(() => {
  // 使用 forceUpdate 来触发重新计算
  const _ = forceUpdate.value;
  
  const activeIndex = props.tabs.findIndex(tab => tab.value === props.modelValue);
  
  if (activeIndex === -1 || !tabsContainer.value || !tabItems.value[activeIndex]) {
    return { 
      left: '0px',
      opacity: '0'
    };
  }

  const containerRect = tabsContainer.value.getBoundingClientRect();
  const activeTabRect = tabItems.value[activeIndex]!.getBoundingClientRect();
  
  // 计算滑动条相对于容器的位置（tab中心位置）
  const left = activeTabRect.left - containerRect.left + activeTabRect.width / 2;
  
  return {
    left: `${left}px`,
    opacity: '1'
  };
});

let resizeObserver: ResizeObserver | null = null;
let windowResizeHandler: (() => void) | null = null;

// 监听 modelValue 变化，确保滑动条位置更新
watch(() => props.modelValue, () => {
  nextTick(() => {
    updateSliderPosition();
  });
});

// 监听 tabItems refs 更新
watch(() => tabItems.value.length, () => {
  nextTick(() => {
    if (tabItems.value.length > 0 && tabsContainer.value) {
      setupResizeObserver();
      updateSliderPosition();
    }
  });
});

// 设置 ResizeObserver 监听
function setupResizeObserver() {
  if (resizeObserver) {
    resizeObserver.disconnect();
  }
  
  if (tabsContainer.value) {
    resizeObserver = new ResizeObserver(() => {
      updateSliderPosition();
    });
    resizeObserver.observe(tabsContainer.value);
    
    // 监听每个 tab item 的大小变化
    tabItems.value.forEach(item => {
      if (item) {
        resizeObserver!.observe(item);
      }
    });
  }
}

// 监听 tabs 变化，清空并重新获取 refs
watch(() => props.tabs, () => {
  nextTick(() => {
    // tabs 变化时，refs 会重新绑定
    tabItems.value = [];
    updateSliderPosition();
    // 重新设置 ResizeObserver
    setupResizeObserver();
  });
}, { deep: true });

onMounted(() => {
  // 确保初始化时计算正确的位置
  nextTick(() => {
    updateSliderPosition();
    setupResizeObserver();
    
    // 监听窗口大小变化
    windowResizeHandler = () => {
      updateSliderPosition();
    };
    window.addEventListener('resize', windowResizeHandler);
  });
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
    resizeObserver = null;
  }
  if (windowResizeHandler) {
    window.removeEventListener('resize', windowResizeHandler);
    windowResizeHandler = null;
  }
});

function handleTabClick(value: string | number, disabled?: boolean) {
  if (disabled) {
    return;
  }
  if (value !== props.modelValue) {
    emits('update:modelValue', value);
    emits('change', value);
  }
}
</script>

<style scoped lang="scss">
.b-tabs {
  position: relative;
  display: flex;
  flex-direction: row;
  gap: v-bind('`${props.gap}px`');
  justify-content: center;
  font-size: v-bind('`${props.fontSize}px`');
  margin-bottom: v-bind('`${props.marginBottom}px`');
  padding-bottom: 8px; // 为滑动条留出空间

  &-item {
    transition: color 0.3s ease;
    color: var(--text-secondary);
    position: relative;
    z-index: 1;
    user-select: none;
    white-space: nowrap;
    line-height: 1.5; // 确保行高统一

    &.active {
      color: var(--primary-color);
      font-weight: bold;
    }

    &.disabled {
      cursor: not-allowed;
      opacity: 0.5;
      color: var(--text-secondary);
    }

    &:hover:not(.active):not(.disabled) {
      color: var(--text-color);
    }
  }

  &-slider {
    position: absolute;
    height: 4px;
    width: 60px;
    background: var(--primary-color);
    border-radius: 2px;
    bottom: 0;
    transition: left 0.3s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.2s ease;
    transform: translateX(-50%);
    z-index: 0;
    will-change: left;
    pointer-events: none;
  }
}
</style>

