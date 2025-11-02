<template>
  <Teleport to="body">
    <Transition name="mask" appear>
      <div
        v-if="visible"
        class="mask"
        @click="handleMaskClick"
      >
        <div
          class="mask-content"
          @click.stop
        >
          <slot />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
interface Props {
  visible: boolean
  maskClosable?: boolean
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  maskClosable: true
})

const emit = defineEmits<Emits>()

const handleMaskClick = () => {
  if (props.maskClosable) {
    emit('update:visible', false)
    emit('close')
  }
}
</script>

<style scoped lang="scss">
.mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;

  &-content {
    position: relative;
  }
}

.mask-enter-active,
.mask-leave-active {
  transition: opacity 0.3s ease;
}

.mask-enter-from,
.mask-leave-to {
  opacity: 0;
}
</style>