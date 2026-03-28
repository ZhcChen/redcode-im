<template>
  <StatisticCard :title="t('workplace.banner.title')">
    <div class="banner-content">
      <a-typography-title :heading="5" style="margin: 0">
        {{ $t('workplace.welcome') }} {{ userInfo.name }}
      </a-typography-title>
    </div>
  </StatisticCard>
</template>

<script lang="ts" setup>
  import { computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { useUserStore } from '@/store';
  import StatisticCard from '@/components/statistic-card/index.vue';

  const userStore = useUserStore();
  const { t } = useI18n();
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
