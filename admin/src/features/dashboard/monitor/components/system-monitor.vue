<template>
  <a-card class="system-monitor" title="系统监控" :bordered="false">
    <div class="monitor-content">
      <div v-for="item in monitorData" :key="item.label" class="monitor-item">
        <div class="monitor-label">{{ item.label }}</div>
        <div class="monitor-value">
          <a-progress
            :percent="item.value"
            :status="item.status"
            :stroke-width="8"
            :show-text="false"
          />
          <span class="monitor-number">{{ item.value }}%</span>
        </div>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import { getSystemMonitor } from '@/api/dashboard';

  interface MonitorItem {
    label: string;
    value: number;
    status: 'normal' | 'warning' | 'danger';
  }

  const monitorData = ref<MonitorItem[]>([
    {
      label: 'CPU 使用率',
      value: 0,
      status: 'normal',
    },
    {
      label: '内存使用率',
      value: 0,
      status: 'normal',
    },
    {
      label: '磁盘使用率',
      value: 0,
      status: 'normal',
    },
    {
      label: '网络连接',
      value: 0,
      status: 'normal',
    },
  ]);

  let timer: number | null = null;

  const getStatus = (value: number): 'normal' | 'warning' | 'danger' => {
    if (value < 60) return 'normal';
    if (value < 80) return 'warning';
    return 'danger';
  };

  const fetchMonitorData = async () => {
    try {
      const { data } = await getSystemMonitor();
      if (data) {
        monitorData.value = [
          {
            label: 'CPU 使用率',
            value: Math.round(data.cpu * 100),
            status: getStatus(data.cpu * 100),
          },
          {
            label: '内存使用率',
            value: Math.round(data.memory * 100),
            status: getStatus(data.memory * 100),
          },
          {
            label: '磁盘使用率',
            value: Math.round(data.disk * 100),
            status: getStatus(data.disk * 100),
          },
          {
            label: '网络连接',
            value: Math.min(data.connections * 10, 100), // 转换为0-100的范围
            status: 'normal',
          },
        ];
      }
    } catch (error) {
      // 使用模拟数据
      monitorData.value = [
        {
          label: 'CPU 使用率',
          value: 35,
          status: 'normal',
        },
        {
          label: '内存使用率',
          value: 62,
          status: 'warning',
        },
        {
          label: '磁盘使用率',
          value: 28,
          status: 'normal',
        },
        {
          label: '网络连接',
          value: 45,
          status: 'normal',
        },
      ];
    }
  };

  onMounted(() => {
    fetchMonitorData();
    // 每3秒更新一次
    timer = window.setInterval(fetchMonitorData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style lang="less" scoped>
  .system-monitor {
    .monitor-content {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 24px;
    }

    .monitor-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px;
      background-color: var(--color-fill-1);
      border-radius: 6px;
      transition: background-color 0.2s;

      &:hover {
        background-color: var(--color-fill-2);
      }
    }

    .monitor-label {
      color: var(--color-text-2);
      font-weight: 500;
      font-size: 14px;
    }

    .monitor-value {
      display: flex;
      flex: 1;
      gap: 12px;
      align-items: center;
      margin-left: 20px;
    }

    :deep(.arco-progress-bar) {
      flex: 1;
    }

    .monitor-number {
      min-width: 40px;
      color: var(--color-text-1);
      font-weight: 600;
      font-size: 14px;
      text-align: right;
    }
  }

  @media (max-width: @screen-lg) {
    .system-monitor .monitor-content {
      grid-template-columns: 1fr;
    }
  }
</style>
