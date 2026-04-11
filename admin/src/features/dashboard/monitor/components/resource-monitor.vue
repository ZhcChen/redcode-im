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
  import { ref, onMounted, onUnmounted } from 'vue';
  import { getSystemStats, type SystemStats } from '@/services/dashboard';

  const systemStats = ref<SystemStats>();
  let timer: number | null = null;

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
    // 每3秒更新一次
    timer = window.setInterval(fetchData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
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
      border: 1px solid var(--color-border-2);
      border-radius: 8px;
      transition: box-shadow 0.2s;

      &:hover {
        box-shadow: 0 2px 8px rgb(0 0 0 / 8%);
      }
    }

    .resource-icon {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 48px;
      height: 48px;
      margin-bottom: 16px;
      font-size: 24px;
      border-radius: 8px;

      .memory & {
        color: #2db7f5;
        background-color: #e6f7ff;
      }

      .storage & {
        color: #52c41a;
        background-color: #f6ffed;
      }

      .load & {
        color: #faad14;
        background-color: #fff7e6;
      }
    }

    .resource-info {
      h3 {
        margin: 0 0 12px;
        color: var(--color-text-1);
        font-weight: 600;
        font-size: 16px;
      }

      .resource-stats {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 12px;

        .current {
          color: var(--color-text-1);
          font-weight: 700;
          font-size: 24px;
        }

        .total {
          color: var(--color-text-3);
          font-size: 12px;
        }
      }

      .load-indicator {
        display: flex;
        gap: 8px;
        align-items: center;

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
          color: var(--color-text-2);
          font-size: 12px;
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
