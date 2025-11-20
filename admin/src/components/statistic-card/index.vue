<template>
  <a-card class="statistic-card" :title="title" :bordered="false">
    <template v-if="$slots.extra" #extra>
      <slot name="extra"></slot>
    </template>
    <div class="statistic-content">
      <slot></slot>
    </div>
  </a-card>
</template>

<script setup lang="ts">
  defineOptions({
    name: 'StatisticCard',
  });

  defineProps<{
    title?: string;
  }>();
</script>

<style scoped>
  .statistic-card {
    margin-bottom: 16px;
    background-color: var(--color-bg-2);
    border: 1px solid rgb(var(--gray-2));
    border-radius: 4px;
  }

  .statistic-content {
    padding: 16px 0;
  }

  :deep(.arco-card-header) {
    padding: 16px 20px;
    border-bottom: 1px solid rgb(var(--gray-2));
  }

  :deep(.arco-card-body) {
    padding: 0 20px 16px;
  }
</style>
