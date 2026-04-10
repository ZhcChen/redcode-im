<template>
  <LocaleProvider>
    <slot />
    <GlobalSetting />
  </LocaleProvider>
</template>

<script lang="ts" setup>
  import GlobalSetting from '@/components/global-setting/index.vue';
  import LocaleProvider from './locale-provider.vue';
</script>
