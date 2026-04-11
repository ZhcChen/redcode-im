<template>
  <a-card class="network-status" title="网络状态" :bordered="false">
    <div class="network-info">
      <div class="connection-info">
        <div class="info-item">
          <div class="info-icon">
            <icon-wifi />
          </div>
          <div class="info-content">
            <h4>活跃连接</h4>
            <span class="info-value">{{ networkStats.connections }}</span>
            <span class="info-unit">个连接</span>
          </div>
        </div>

        <div class="info-item">
          <div class="info-icon">
            <icon-download />
          </div>
          <div class="info-content">
            <h4>网络入口</h4>
            <span class="info-value">{{
              formatBytes(networkStats.network_in)
            }}</span>
            <span class="info-unit">/s</span>
          </div>
        </div>

        <div class="info-item">
          <div class="info-icon">
            <icon-upload />
          </div>
          <div class="info-content">
            <h4>网络出口</h4>
            <span class="info-value">{{
              formatBytes(networkStats.network_out)
            }}</span>
            <span class="info-unit">/s</span>
          </div>
        </div>
      </div>

      <div class="status-indicator">
        <div class="status-item">
          <span class="status-label">网络状态</span>
          <span class="status-value" :class="networkStatus.class">
            {{ networkStatus.text }}
          </span>
        </div>
        <div class="status-item">
          <span class="status-label">带宽使用</span>
          <span class="status-value">{{ Math.round(bandwidthUsage) }}%</span>
        </div>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { ref, computed, onMounted, onUnmounted } from 'vue';
  import { getSystemMonitor, type SystemMonitor } from '@/services/dashboard';

  interface NetworkStats extends SystemMonitor {
    network_in: number;
    network_out: number;
  }

  const networkStats = ref<NetworkStats>({
    cpu: 0,
    memory: 0,
    disk: 0,
    network_in: 0,
    network_out: 0,
    connections: 0,
  });

  const networkStatus = computed(() => {
    if (networkStats.value.connections < 50) {
      return { text: '正常', class: 'status-normal' };
    }
    if (networkStats.value.connections < 100) {
      return { text: '繁忙', class: 'status-warning' };
    }
    return { text: '拥塞', class: 'status-danger' };
  });

  const bandwidthUsage = computed(() => {
    const totalBits =
      (networkStats.value.network_in + networkStats.value.network_out) * 8;
    const maxBandwidth = 1000000; // 假设1Gbps
    return (totalBits / maxBandwidth) * 100;
  });

  const formatBytes = (bytes: number): string => {
    if (bytes === 0) return '0';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / k ** i).toFixed(1)) + sizes[i];
  };

  let timer: number | null = null;

  const fetchNetworkData = async () => {
    try {
      const { data } = await getSystemMonitor();
      if (data) {
        // 模拟网络数据
        networkStats.value = {
          ...data,
          network_in: Math.random() * 1024 * 1024, // 0-1MB/s
          network_out: Math.random() * 1024 * 1024, // 0-1MB/s
        };
      }
    } catch (error) {
      // 使用模拟数据
      networkStats.value = {
        cpu: 0,
        memory: 0,
        disk: 0,
        network_in: 512000, // 512KB/s
        network_out: 256000, // 256KB/s
        connections: 68,
      };
    }
  };

  onMounted(() => {
    fetchNetworkData();
    // 每3秒更新一次
    timer = window.setInterval(fetchNetworkData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style lang="less" scoped>
  .network-status {
    .network-info {
      display: flex;
      flex-direction: column;
      gap: 24px;
    }

    .connection-info {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .info-item {
      display: flex;
      gap: 12px;
      align-items: center;
      padding: 12px;
      background-color: var(--color-fill-1);
      border-radius: 6px;
      transition: background-color 0.2s;

      &:hover {
        background-color: var(--color-fill-2);
      }

      .info-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 40px;
        height: 40px;
        color: var(--color-primary-6);
        font-size: 18px;
        background-color: var(--color-primary-light-1);
        border-radius: 6px;
      }

      .info-content {
        display: flex;
        flex-direction: column;
        gap: 2px;

        h4 {
          margin: 0;
          color: var(--color-text-2);
          font-size: 14px;
        }

        .info-value {
          color: var(--color-text-1);
          font-weight: 700;
          font-size: 20px;
        }

        .info-unit {
          color: var(--color-text-3);
          font-size: 12px;
        }
      }
    }

    .status-indicator {
      display: flex;
      justify-content: space-between;
      padding-top: 16px;
      border-top: 1px solid var(--color-border-2);

      .status-item {
        display: flex;
        flex-direction: column;
        gap: 4px;
        align-items: center;

        .status-label {
          color: var(--color-text-3);
          font-size: 12px;
        }

        .status-value {
          font-weight: 600;
          font-size: 14px;

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
  }
</style>
