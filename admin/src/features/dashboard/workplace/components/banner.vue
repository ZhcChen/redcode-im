<template>
  <StatisticCard title="工作台">
    <div class="banner-content">
      <a-typography-title :heading="5" style="margin: 0">
        {{ $t('workplace.welcome') }} {{ userInfo.name }}
      </a-typography-title>
    </div>
  </StatisticCard>
</template>

<script lang="ts" setup>
  import { computed } from 'vue';
  import { useUserStore } from '@/store';
  import StatisticCard from '@/components/statistic-card/index.vue';

  const userStore = useUserStore();
  const userInfo = computed(() => {
    return {
      name: userStore.name,
    };
  });
</script>

<style scoped lang="less">
  .banner-content {
    padding: 8px 0;
  }
</style>
