<script setup lang="ts">
// defineProps, defineEmits 和 withDefaults 现在是编译器宏，无需导入

const props = withDefaults(defineProps<{
  modelValue: boolean | string | number | null | undefined
}>(), {
  modelValue: false
})

const emit = defineEmits(['update:modelValue'])

const onClick = () => {
  emit('update:modelValue', !props.modelValue);
}
</script>

<template>
  <div class="b-radio" @click="onClick()">
    <div class="b-radio-selected" v-if="modelValue">
      <img src="@/assets/image/icon/selected.svg" alt="">
    </div>
    <div class="b-radio-un" v-else></div>
  </div>
</template>

<style lang="scss" scoped>
.b-radio {
  height: 16px;
  width: 16px;
  @include flex-center;
  cursor: pointer;
  user-select: none; // 防止文字被选中

  &-selected {
    height: 14px;
    width: 14px;
    border-radius: 50%;
    @include flex-center;
    background: var(--primary-color);

    img {
      height: 50%;
      width: 50%;
    }
  }

  &-un {
    height: 14px;
    width: 14px;
    border-radius: 50%;
    border: 1px solid var(--primary-color);
    @include flex-center;
    background: var(--bg-color);
    box-sizing: border-box;
  }
}
</style>