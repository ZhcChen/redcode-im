<script setup lang="ts">
const props = withDefaults(defineProps<{
  modelValue: boolean
  disabled?: boolean
}>(), {
  modelValue: false,
  disabled: false
})

const emit = defineEmits(['update:modelValue'])

const onClick = () => {
  if (!props.disabled) {
    emit('update:modelValue', !props.modelValue)
  }
}
</script>

<template>
  <div
    class="b-checkbox"
    :class="{ 'disabled': disabled }"
    @click="onClick()"
  >
    <div class="b-checkbox-selected" v-if="modelValue">
      <img src="@/assets/image/icon/selected.svg" alt="">
    </div>
    <div class="b-checkbox-un" v-else></div>
  </div>
</template>

<style lang="scss" scoped>
.b-checkbox {
  height: 16px;
  width: 16px;
  @include flex-center;
  user-select: none;

  &.disabled {
    opacity: 0.5;
    pointer-events: none;
  }

  &-selected {
    height: 14px;
    width: 14px;
    border-radius: 3px;
    @include flex-center;
    background: var(--primary-color);

    img {
      height: 70%;
      width: 70%;
    }
  }

  &-un {
    height: 14px;
    width: 14px;
    border-radius: 3px;
    border: 1px solid var(--primary-color);
    @include flex-center;
    background: var(--bg-color);
    box-sizing: border-box;
  }
}
</style>
