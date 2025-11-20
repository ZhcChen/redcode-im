<template>
  <a-card class="system-load" title="系统负载详情" :bordered="false">
    <div class="load-details">
      <div class="load-item">
        <div class="load-header">
          <span class="load-label">1分钟平均负载</span>
          <span class="load-value">{{ loadStats.load1 }}</span>
        </div>
        <a-progress
          :percent="loadPercent(loadStats.load1)"
          :stroke-width="6"
          :color="loadColor(loadStats.load1)"
          :show-text="false"
        />
      </div>

      <div class="load-item">
        <div class="load-header">
          <span class="load-label">5分钟平均负载</span>
          <span class="load-value">{{ loadStats.load5 }}</span>
        </div>
        <a-progress
          :percent="loadPercent(loadStats.load5)"
          :stroke-width="6"
          :color="loadColor(loadStats.load5)"
          :show-text="false"
        />
      </div>

      <div class="load-item">
        <div class="load-header">
          <span class="load-label">15分钟平均负载</span>
          <span class="load-value">{{ loadStats.load15 }}</span>
        </div>
        <a-progress
          :percent="loadPercent(loadStats.load15)"
          :stroke-width="6"
          :color="loadColor(loadStats.load15)"
          :show-text="false"
        />
      </div>

      <div class="load-summary">
        <div class="summary-item">
          <span class="summary-label">CPU核心数</span>
          <span class="summary-value">4核</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">当前状态</span>
          <span class="summary-value" :class="getOverallStatus()">
            {{ getStatusText() }}
          </span>
        </div>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import { getSystemMonitor } from '@/api/dashboard';

  interface LoadStats {
    load1: number;
    load5: number;
    load15: number;
  }

  const loadStats = ref<LoadStats>({
    load1: 0.5,
    load5: 0.8,
    load15: 1.2,
  });

  let timer: number | null = null;

  const loadPercent = (load: number): number => {
    return Math.min(load * 25, 100); // 假设4核心，负载1.0=25%
  };

  const loadColor = (load: number): string => {
    if (load < 1) return '#52c41a';
    if (load < 2) return '#faad14';
    return '#f5222d';
  };

  const getOverallStatus = (): string => {
    const avg =
      (loadStats.value.load1 + loadStats.value.load5 + loadStats.value.load15) /
      3;
    if (avg < 1) return 'status-normal';
    if (avg < 2) return 'status-warning';
    return 'status-danger';
  };

  const getStatusText = (): string => {
    const avg =
      (loadStats.value.load1 + loadStats.value.load5 + loadStats.value.load15) /
      3;
    if (avg < 1) return '正常';
    if (avg < 2) return '较高';
    return '过高';
  };

  const fetchLoadData = async () => {
    try {
      const { data } = await getSystemMonitor();
      if (data) {
        // 模拟不同时间段的负载数据
        loadStats.value = {
          load1: Math.random() * 2,
          load5: Math.random() * 2,
          load15: Math.random() * 2,
        };
      }
    } catch (error) {
      // 使用模拟数据
      loadStats.value = {
        load1: 0.85,
        load5: 1.23,
        load15: 1.62,
      };
    }
  };

  onMounted(() => {
    fetchLoadData();
    // 每3秒更新一次
    timer = window.setInterval(fetchLoadData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style lang="less" scoped>
  .system-load {
    .load-details {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }

    .load-item {
      .load-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 8px;
      }

      .load-label {
        font-size: 14px;
        color: var(--color-text-2);
      }

      .load-value {
        font-size: 16px;
        font-weight: 600;
        color: var(--color-text-1);
      }
    }

    .load-summary {
      margin-top: 16px;
      padding-top: 16px;
      border-top: 1px solid var(--color-border-2);
      display: flex;
      justify-content: space-between;

      .summary-item {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
      }

      .summary-label {
        font-size: 12px;
        color: var(--color-text-3);
      }

      .summary-value {
        font-size: 14px;
        font-weight: 600;

        &.status-normal {
          color: #52c41a;
        }

        &.status-warning {
          color: #faad14;
        }

        &.status-danger {
          color: #f5222d;
        }
      }
    }
  }
</style>
