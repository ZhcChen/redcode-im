<template>
  <div class="nodes-monitor-wrapper">
    <div class="monitor-header">
      <div class="header-title">
        <icon-apps :size="20" />
        <span>{{ t('monitor.nodes.title') }}</span>
        <a-tag size="small" color="blue" class="node-count-tag">
          {{ t('monitor.nodes.activeCount', { count: nodes.length }) }}
        </a-tag>
      </div>
    </div>

    <a-spin :loading="loading" style="width: 100%">
      <div v-if="nodes.length === 0" class="empty-container">
        <a-empty :description="t('monitor.nodes.empty')" />
      </div>
      <div v-else class="nodes-grid">
        <a-card
          v-for="node in nodes"
          :key="node.nodeId"
          class="node-premium-card"
          :bordered="false"
        >
          <div class="node-card-inner">
            <div class="node-header-row">
              <div class="node-instance-type">
                <div class="node-icon">
                  <icon-computer :size="18" />
                </div>
                <a-tag
                  size="small"
                  color="arcoblue"
                  variant="outline"
                  class="instance-label"
                  >{{ t('monitor.nodes.instanceLabel') }}</a-tag
                >
              </div>
              <a-badge status="success">
                <template #text>
                  <span class="status-text">{{ t('monitor.nodes.running') }}</span>
                </template>
              </a-badge>
            </div>

            <div class="node-identity-section">
              <div class="node-id-wrapper">
                <a-tooltip :content="t('monitor.nodes.idTooltip', { id: node.nodeId })">
                  <div class="node-id">{{ node.nodeId }}</div>
                </a-tooltip>
              </div>
              <div class="node-addr">
                <icon-link :size="12" />
                <span>{{ node.address }}</span>
              </div>
            </div>

            <div class="node-specs-section">
              <div class="spec-item">
                <icon-thunderbolt :size="12" />
                <span>{{ t('monitor.nodes.cpuCores', { count: node.cpuCount }) }}</span>
              </div>
              <div class="spec-item">
                <icon-drive-file :size="12" />
                <span>{{
                  t('monitor.nodes.totalMemory', {
                    memory: formatMemory(node.totalMemory),
                  })
                }}</span>
              </div>
            </div>

            <a-divider />

            <div class="metrics-section">
              <div class="metric-group">
                <div class="metric-label-row">
                  <span class="label">{{ t('monitor.nodes.cpuLoad') }}</span>
                  <span class="value"
                    >{{ (node.cpuUsage * 100).toFixed(1) }}%</span
                  >
                </div>
                <a-progress
                  :percent="node.cpuUsage"
                  :color="getUsageColor(node.cpuUsage)"
                  :show-text="false"
                  size="small"
                  class="premium-progress"
                />
              </div>

              <div class="metric-group">
                <div class="metric-label-row">
                  <span class="label">{{ t('monitor.nodes.memoryUsage') }}</span>
                  <span class="value"
                    >{{ (node.memoryUsage * 100).toFixed(1) }}%</span
                  >
                </div>
                <a-progress
                  :percent="node.memoryUsage"
                  :color="getUsageColor(node.memoryUsage)"
                  :show-text="false"
                  size="small"
                  class="premium-progress"
                />
              </div>

              <div class="metric-group">
                <div class="metric-label-row">
                  <span class="label">{{ t('monitor.nodes.diskUsage') }}</span>
                  <span class="value"
                    >{{ (node.diskUsage * 100).toFixed(1) }}%</span
                  >
                </div>
                <a-progress
                  :percent="node.diskUsage"
                  :color="getUsageColor(node.diskUsage)"
                  :show-text="false"
                  size="small"
                  class="premium-progress"
                />
              </div>
            </div>

            <div class="stats-footer">
              <div class="stat-item">
                <div class="stat-value">{{ node.connectedUsers }}</div>
                <div class="stat-label">{{ t('monitor.nodes.onlineUsers') }}</div>
              </div>
              <div class="stat-item">
                <div class="stat-value">{{ node.activeRooms }}</div>
                <div class="stat-label">{{ t('monitor.nodes.activeRooms') }}</div>
              </div>
              <div class="stat-item">
                <div class="stat-value uptime">{{
                  formatDate(node.lastHeartbeat)
                }}</div>
                <div class="stat-label">{{ t('monitor.nodes.lastReport') }}</div>
              </div>
            </div>
          </div>
        </a-card>
      </div>
    </a-spin>
  </div>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import { useI18n } from 'vue-i18n';
  import dayjs from 'dayjs';
  import { getNodesMonitor, type NodeMonitor } from '@/api/dashboard';
  import useLoading from '@/hooks/loading';

  const { loading, setLoading } = useLoading(true);
  const { t } = useI18n();
  const nodes = ref<NodeMonitor[]>([]);
  let timer: any = null;

  const fetchData = async () => {
    try {
      const { data } = await getNodesMonitor();
      nodes.value = data;
    } catch (err) {
      console.error('failed to fetch node monitor list', err);
    } finally {
      if (loading.value) setLoading(false);
    }
  };

  const getUsageColor = (usage: number) => {
    if (usage > 0.8) return '#F53F3F';
    if (usage > 0.6) return '#FF7D00';
    return '#00B42A';
  };

  const formatMemory = (bytes: number) => {
    if (!bytes) return '0 GB';
    const gb = bytes / (1024 * 1024 * 1024);
    return `${gb.toFixed(1)} GB`;
  };

  const formatDate = (date: string) => {
    return dayjs(date).format('HH:mm:ss');
  };

  onMounted(() => {
    fetchData();
    timer = setInterval(fetchData, 5000);
  });

  onUnmounted(() => {
    if (timer) clearInterval(timer);
  });
</script>

<style lang="less" scoped>
  .nodes-monitor-wrapper {
    margin-top: 16px;
  }

  .monitor-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 24px;
    padding: 0 4px;

    .header-title {
      display: flex;
      gap: 12px;
      align-items: center;
      color: var(--color-text-1);
      font-weight: 600;
      font-size: 18px;

      .node-count-tag {
        margin-left: 8px;
        font-weight: normal;
      }
    }
  }

  .nodes-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
    gap: 20px;
  }

  .node-premium-card {
    overflow: hidden;
    background: var(--color-bg-2);
    border: 1px solid var(--color-fill-3);
    border-radius: 14px;
    box-shadow: 0 4px 14px 0 var(--color-fill-1);
    transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);

    &:hover {
      border-color: var(--color-primary-light-3);
      box-shadow: 0 12px 24px 0 var(--color-fill-2);
      transform: translateY(-4px);
    }

    .node-card-inner {
      padding: 0;
    }

    .node-header-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px 20px 12px;

      .node-instance-type {
        display: flex;
        gap: 8px;
        align-items: center;

        .node-icon {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 32px;
          height: 32px;
          color: var(--color-primary-6);
          background: var(--color-primary-light-1);
          border-radius: 8px;
        }

        .instance-label {
          font-weight: 500;
          font-size: 12px;
        }
      }

      .status-text {
        color: var(--color-text-2);
        font-weight: 600;
        font-size: 11px;
        letter-spacing: 0.5px;
      }
    }

    .node-identity-section {
      padding: 0 20px 16px;

      .node-id-wrapper {
        margin-bottom: 8px;
        padding: 10px 12px;
        background: var(--color-fill-1);
        border: 1px solid var(--color-fill-2);
        border-radius: 8px;

        .node-id {
          color: var(--color-text-1);
          font-weight: 600;
          font-size: 15px;
          font-family: 'Fira Code', 'Roboto Mono', monospace;
          line-height: 1.4;
          word-break: break-all;
          cursor: help;
        }
      }

      .node-addr {
        display: flex;
        gap: 6px;
        align-items: center;
        color: var(--color-text-3);
        font-size: 12px;
        font-family: monospace;
      }
    }

    .node-specs-section {
      display: flex;
      gap: 16px;
      padding: 0 20px 8px;

      .spec-item {
        display: flex;
        gap: 6px;
        align-items: center;
        padding: 4px 8px;
        color: var(--color-text-2);
        font-size: 12px;
        background: var(--color-primary-light-1);
        border-radius: 4px;

        span {
          font-weight: 500;
        }

        .arco-icon {
          color: var(--color-primary-6);
        }
      }
    }

    .metrics-section {
      display: flex;
      flex-direction: column;
      gap: 14px;
      padding: 0 20px 20px;
    }

    .metric-group {
      .metric-label-row {
        display: flex;
        justify-content: space-between;
        margin-bottom: 6px;
        font-size: 12px;

        .label {
          color: var(--color-text-3);
          font-weight: 600;
        }

        .value {
          color: var(--color-text-1);
          font-weight: 600;
        }
      }

      .premium-progress {
        :deep(.arco-progress-line-bar) {
          height: 6px !important;
          border-radius: 3px;
        }
      }
    }

    .stats-footer {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1px;
      background: var(--color-fill-3);
      border-top: 1px solid var(--color-fill-3);

      .stat-item {
        display: flex;
        flex-direction: column;
        gap: 4px;
        align-items: center;
        padding: 12px 0;
        background: var(--color-fill-1);

        .stat-value {
          color: var(--color-text-1);
          font-weight: 700;
          font-size: 14px;

          &.uptime {
            color: var(--color-primary-6);
            font-size: 12px;
          }
        }

        .stat-label {
          color: var(--color-text-4);
          font-weight: 600;
          font-size: 10px;
          letter-spacing: 0.5px;
        }
      }
    }
  }

  .empty-container {
    padding: 60px 0;
    background: var(--color-bg-2);
    border: 2px dashed var(--color-fill-3);
    border-radius: 12px;
  }

  :deep(.arco-divider-horizontal) {
    margin: 4px 0 16px;
    border-bottom-style: dashed;
  }
</style>
