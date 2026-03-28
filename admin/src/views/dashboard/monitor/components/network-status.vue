<template>
  <a-card
    class="network-status"
    :title="t('monitor.network.title')"
    :bordered="false"
  >
    <div class="network-info">
      <div class="connection-info">
        <div class="info-item">
          <div class="info-icon">
            <icon-wifi />
          </div>
          <div class="info-content">
            <h4>{{ t('monitor.network.activeConnections') }}</h4>
            <span class="info-value">{{ networkStats.connections }}</span>
            <span class="info-unit">{{
              t('monitor.network.connectionsUnit')
            }}</span>
          </div>
        </div>

        <div class="info-item">
          <div class="info-icon">
            <icon-download />
          </div>
          <div class="info-content">
            <h4>{{ t('monitor.network.ingress') }}</h4>
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
            <h4>{{ t('monitor.network.egress') }}</h4>
            <span class="info-value">{{
              formatBytes(networkStats.network_out)
            }}</span>
            <span class="info-unit">/s</span>
          </div>
        </div>
      </div>

      <div class="status-indicator">
        <div class="status-item">
          <span class="status-label">{{
            t('monitor.network.statusLabel')
          }}</span>
          <span class="status-value" :class="networkStatus.class">
            {{ networkStatus.text }}
          </span>
        </div>
        <div class="status-item">
          <span class="status-label">{{
            t('monitor.network.bandwidthUsage')
          }}</span>
          <span class="status-value">{{ Math.round(bandwidthUsage) }}%</span>
        </div>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { computed, onMounted, onUnmounted, ref } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { getSystemMonitor, type SystemMonitor } from '@/api/dashboard';

  interface NetworkStats extends SystemMonitor {
    network_in: number;
    network_out: number;
  }

  const { t } = useI18n();
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
      return {
        text: t('monitor.network.status.normal'),
        class: 'status-normal',
      };
    }
    if (networkStats.value.connections < 100) {
      return {
        text: t('monitor.network.status.busy'),
        class: 'status-warning',
      };
    }
    return {
      text: t('monitor.network.status.congested'),
      class: 'status-danger',
    };
  });

  const bandwidthUsage = computed(() => {
    const totalBits =
      (networkStats.value.network_in + networkStats.value.network_out) * 8;
    const maxBandwidth = 1000000;
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
        networkStats.value = {
          ...data,
          network_in: Math.random() * 1024 * 1024,
          network_out: Math.random() * 1024 * 1024,
        };
      }
    } catch (error) {
      networkStats.value = {
        cpu: 0,
        memory: 0,
        disk: 0,
        network_in: 512000,
        network_out: 256000,
        connections: 68,
      };
    }
  };

  onMounted(() => {
    fetchNetworkData();
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
      align-items: center;
      gap: 12px;
      padding: 12px;
      background-color: var(--color-fill-1);
      border-radius: 6px;
      transition: background-color 0.2s;

      &:hover {
        background-color: var(--color-fill-2);
      }

      .info-icon {
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
        background-color: var(--color-primary-light-1);
        color: var(--color-primary-6);
        border-radius: 6px;
        font-size: 18px;
      }

      .info-content {
        display: flex;
        flex-direction: column;
        gap: 2px;

        h4 {
          margin: 0;
          font-size: 14px;
          color: var(--color-text-2);
        }

        .info-value {
          font-size: 20px;
          font-weight: 700;
          color: var(--color-text-1);
        }

        .info-unit {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
    }

    .status-indicator {
      padding-top: 16px;
      border-top: 1px solid var(--color-border-2);
      display: flex;
      justify-content: space-between;

      .status-item {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;

        .status-label {
          font-size: 12px;
          color: var(--color-text-3);
        }

        .status-value {
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
  }
</style>
