<script setup lang="ts">

</script>

<template>
  <div class="b-button">
    <slot></slot>
  </div>
</template>

<style lang="scss" scoped>
  .b-button {
    height: 44px;
    width: 100%;
    background: var(--primary-color);
    color: var(--text-white-color);
    @include flex-center;
    border-radius: 22px;
    font-size: 14px;
  }
</style>