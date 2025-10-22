<template>
  <a-card class="resource-monitor" title="资源监控" :bordered="false">
    <div class="resource-grid">
      <div class="resource-card memory">
        <div class="resource-icon">
          <icon-memory />
        </div>
        <div class="resource-info">
          <h3>内存使用</h3>
          <div class="resource-stats">
            <span class="current">{{ systemStats?.memoryUsage || 0 }}%</span>
            <span class="total">总计: 16GB</span>
          </div>
          <a-progress
            :percent="systemStats?.memoryUsage || 0"
            :stroke-width="6"
            color="#2db7f5"
          />
        </div>
      </div>

      <div class="resource-card storage">
        <div class="resource-icon">
          <icon-folder />
        </div>
        <div class="resource-info">
          <h3>存储空间</h3>
          <div class="resource-stats">
            <span class="current">{{ systemStats?.storageUsage || 0 }}%</span>
            <span class="total">总计: 500GB</span>
          </div>
          <a-progress
            :percent="systemStats?.storageUsage || 0"
            :stroke-width="6"
            color="#52c41a"
          />
        </div>
      </div>

      <div class="resource-card load">
        <div class="resource-icon">
          <icon-cpu />
        </div>
        <div class="resource-info">
          <h3>系统负载</h3>
          <div class="resource-stats">
            <span class="current">{{ systemStats?.systemLoad || 0 }}</span>
            <span class="total">平均负载: 1.2</span>
          </div>
          <div class="load-indicator">
            <span
              class="load-dot"
              :class="getLoadClass(systemStats?.systemLoad || 0)"
            ></span>
            <span class="load-text">{{
              getLoadText(systemStats?.systemLoad || 0)
            }}</span>
          </div>
        </div>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { ref, onMounted } from 'vue';
  import { getSystemStats, type SystemStats } from '@/api/dashboard';

  const systemStats = ref<SystemStats>();

  const getLoadClass = (load: number): string => {
    if (load < 1) return 'load-normal';
    if (load < 2) return 'load-warning';
    return 'load-danger';
  };

  const getLoadText = (load: number): string => {
    if (load < 1) return '正常';
    if (load < 2) return '较高';
    return '过高';
  };

  const fetchData = async () => {
    try {
      const { data } = await getSystemStats();
      systemStats.value = data;
    } catch (error) {
      // 使用模拟数据
      systemStats.value = {
        totalUsers: 0,
        onlineUsers: 0,
        totalRooms: 0,
        activeRooms: 0,
        totalMessages: 0,
        todayMessages: 0,
        systemLoad: 1.2,
        memoryUsage: 62,
        storageUsage: 28,
      };
    }
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .resource-monitor {
    .resource-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
    }

    .resource-card {
      padding: 20px;
      background: var(--color-bg-1);
      border-radius: 8px;
      border: 1px solid var(--color-border-2);
      transition: box-shadow 0.2s;

      &:hover {
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
      }
    }

    .resource-icon {
      width: 48px;
      height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 8px;
      font-size: 24px;
      margin-bottom: 16px;

      .memory & {
        background-color: #e6f7ff;
        color: #2db7f5;
      }

      .storage & {
        background-color: #f6ffed;
        color: #52c41a;
      }

      .load & {
        background-color: #fff7e6;
        color: #faad14;
      }
    }

    .resource-info {
      h3 {
        font-size: 16px;
        font-weight: 600;
        margin: 0 0 12px 0;
        color: var(--color-text-1);
      }

      .resource-stats {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 12px;

        .current {
          font-size: 24px;
          font-weight: 700;
          color: var(--color-text-1);
        }

        .total {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }

      .load-indicator {
        display: flex;
        align-items: center;
        gap: 8px;

        .load-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;

          &.load-normal {
            background-color: #52c41a;
          }

          &.load-warning {
            background-color: #faad14;
          }

          &.load-danger {
            background-color: #f5222d;
          }
        }

        .load-text {
          font-size: 12px;
          color: var(--color-text-2);
        }
      }
    }
  }

  @media (max-width: @screen-xl) {
    .resource-monitor .resource-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
