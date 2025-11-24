<template>
  <Teleport to="body">
    <transition name="b-modal-fade">
      <div v-if="visible" class="b-modal-mask" @click="handleMaskClick">
        <div
          class="b-modal-wrapper"
          :style="modalStyle"
          @click.stop
        >
          <header class="b-modal-header" v-if="title || closable">
            <div class="b-modal-title">{{ title }}</div>
            <button
              v-if="closable"
              class="b-modal-close"
              type="button"
              @click="handleClose"
            >
              ×
            </button>
          </header>
          <ScrollContainer class="b-modal-body">
            <slot />
          </ScrollContainer>
        </div>
      </div>
    </transition>
  </Teleport>
</template>

<script setup lang="ts">
import { computed } from "vue";
import ScrollContainer from './ScrollContainer.vue';

const props = withDefaults(
  defineProps<{
    visible: boolean;
    title?: string;
    width?: number | string;
    maskClosable?: boolean;
    closable?: boolean;
  }>(),
  {
    title: "",
    width: 520,
    maskClosable: true,
    closable: true,
  },
);

const emit = defineEmits<{
  (e: "close"): void;
}>();

const modalStyle = computed(() => {
  const widthValue = typeof props.width === "number" ? `${props.width}px` : props.width;
  return {
    width: widthValue,
  };
});

function handleMaskClick(event: MouseEvent) {
  if (event.target !== event.currentTarget) {
    return;
  }

  if (props.maskClosable) {
    emit("close");
  }
}

function handleClose() {
  if (props.closable) {
    emit("close");
  }
}
</script>

<style scoped lang="scss">
.b-modal-fade-enter-active,
.b-modal-fade-leave-active {
  transition: opacity 0.2s ease;
}

.b-modal-fade-enter-from,
.b-modal-fade-leave-to {
  opacity: 0;
}

.b-modal-mask {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 999;
  padding: 32px 16px;
  box-sizing: border-box;
}

.b-modal-wrapper {
  background: #fff;
  border-radius: 18px;
  max-height: 100%;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(15, 23, 42, 0.25);
  animation: b-modal-pop 0.2s ease;
}

.b-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px 0;
}

.b-modal-title {
  font-size: 18px;
  font-weight: 600;
  color: #111827;
}

.b-modal-close {
  border: none;
  background: transparent;
  font-size: 20px;
  color: #6b7280;
  padding: 4px;

  &:hover {
    color: #111827;
  }
}

.b-modal-body {
  padding: 12px 24px 24px;
}

@keyframes b-modal-pop {
  from {
    transform: translateY(12px);
    opacity: 0;
  }

  to {
    transform: translateY(0);
    opacity: 1;
  }
}
</style>
