<template>
  <StatisticCard title="数据统计">
    <a-grid :cols="24" :row-gap="16" class="panel">
      <a-grid-item
        class="panel-col"
        :span="{ xs: 12, sm: 12, md: 12, lg: 12, xl: 12, xxl: 6 }"
      >
        <a-space>
          <a-avatar
            :size="54"
            class="col-avatar"
            style="background-color: #1890ff"
          >
            <icon-user />
          </a-avatar>
          <a-statistic
            title="用户总数"
            :value="systemStats?.totalUsers || 0"
            :value-from="0"
            animation
            show-group-separator
          >
            <template #suffix>人</template>
          </a-statistic>
        </a-space>
      </a-grid-item>
      <a-grid-item
        class="panel-col"
        :span="{ xs: 12, sm: 12, md: 12, lg: 12, xl: 12, xxl: 6 }"
      >
        <a-space>
          <a-avatar
            :size="54"
            class="col-avatar"
            style="background-color: #13c2c2"
          >
            <icon-user-add />
          </a-avatar>
          <a-statistic
            title="在线用户"
            :value="systemStats?.onlineUsers || 0"
            :value-from="0"
            animation
            show-group-separator
          >
            <template #suffix>人</template>
          </a-statistic>
        </a-space>
      </a-grid-item>
      <a-grid-item
        class="panel-col"
        :span="{ xs: 12, sm: 12, md: 12, lg: 12, xl: 12, xxl: 6 }"
      >
        <a-space>
          <a-avatar
            :size="54"
            class="col-avatar"
            style="background-color: #52c41a"
          >
            <icon-message />
          </a-avatar>
          <a-statistic
            title="今日消息"
            :value="systemStats?.todayMessages || 0"
            :value-from="0"
            animation
            show-group-separator
          >
            <template #suffix>条</template>
          </a-statistic>
        </a-space>
      </a-grid-item>
      <a-grid-item
        class="panel-col"
        :span="{ xs: 12, sm: 12, md: 12, lg: 12, xl: 12, xxl: 6 }"
        style="border-right: none"
      >
        <a-space>
          <a-avatar
            :size="54"
            class="col-avatar"
            style="background-color: #faad14"
          >
            <icon-home />
          </a-avatar>
          <a-statistic
            title="活跃房间"
            :value="systemStats?.activeRooms || 0"
            :value-from="0"
            animation
            show-group-separator
          >
            <template #suffix>个</template>
          </a-statistic>
        </a-space>
      </a-grid-item>
    </a-grid>
  </StatisticCard>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import useLoading from '@/hooks/loading';
  import { getSystemStats, type SystemStats } from '@/api/dashboard';
  import StatisticCard from '@/components/statistic-card/index.vue';

  const { setLoading } = useLoading(true);
  const systemStats = ref<SystemStats>();
  let timer: number | null = null;

  const fetchData = async () => {
    try {
      setLoading(true);
      const { data } = await getSystemStats();
      systemStats.value = data;
    } catch (error) {
      // Error handling
    } finally {
      setLoading(false);
    }
  };

  onMounted(() => {
    fetchData();
    // 每3秒轮询一次
    timer = window.setInterval(fetchData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style lang="less" scoped>
  .panel {
    padding: 16px 0 0;
  }

  .panel-col {
    padding-left: 43px;
    border-right: 1px solid rgb(var(--gray-2));
  }

  .col-avatar {
    margin-right: 12px;
    background-color: var(--color-fill-2);
  }

  .up-icon {
    color: rgb(var(--red-6));
  }

  .unit {
    margin-left: 8px;
    color: rgb(var(--gray-8));
    font-size: 12px;
  }
</style>
