<template>
  <div class="nodes-monitor-wrapper">
    <div class="monitor-header">
      <div class="header-title">
        <icon-apps :size="20" />
        <span>集群节点实时监控</span>
        <a-tag size="small" color="blue" class="node-count-tag">
          {{ nodes.length }} 活跃节点
        </a-tag>
      </div>
    </div>

    <a-spin :loading="loading" style="width: 100%">
      <div v-if="nodes.length === 0" class="empty-container">
        <a-empty description="暂无活跃节点，请检查后端服务是否启动" />
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
              <div class="node-identity">
                <div class="node-icon">
                  <icon-computer :size="20" />
                </div>
                <div class="node-info-text">
                  <div class="node-id">{{ node.nodeId }}</div>
                  <div class="node-addr">{{ node.address }}</div>
                </div>
              </div>
              <a-badge status="success" text="RUNNING" />
            </div>

            <a-divider />

            <div class="metrics-section">
              <div class="metric-group">
                <div class="metric-label-row">
                  <span class="label">CPU 负载</span>
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
                  <span class="label">内存占用</span>
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
                  <span class="label">磁盘空间</span>
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
                <div class="stat-label">连接用户</div>
              </div>
              <div class="stat-item">
                <div class="stat-value">{{ node.activeRooms }}</div>
                <div class="stat-label">活跃房间</div>
              </div>
              <div class="stat-item">
                <div class="stat-value uptime">{{
                  formatDate(node.lastHeartbeat)
                }}</div>
                <div class="stat-label">最后报告</div>
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
  import dayjs from 'dayjs';
  import { getNodesMonitor, type NodeMonitor } from '@/api/dashboard';
  import useLoading from '@/hooks/loading';

  const { loading, setLoading } = useLoading(true);
  const nodes = ref<NodeMonitor[]>([]);
  let timer: number | null = null;

  const fetchData = async () => {
    try {
      const { data } = await getNodesMonitor();
      nodes.value = data;
    } catch (err) {
      console.error('获取节点监控列表失败', err);
    } finally {
      if (loading.value) setLoading(false);
    }
  };

  const getUsageColor = (usage: number) => {
    if (usage > 0.8) return '#F53F3F';
    if (usage > 0.6) return '#FF7D00';
    return '#00B42A';
  };

  const formatDate = (date: string) => {
    return dayjs(date).format('HH:mm:ss');
  };

  onMounted(() => {
    fetchData();
    timer = window.setInterval(fetchData, 10000);
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
    grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
    gap: 20px;
  }

  .node-premium-card {
    overflow: hidden;
    background: var(--color-bg-2);
    border: 1px solid var(--color-fill-3);
    border-radius: 12px;
    box-shadow: 0 4px 14px 0 var(--color-fill-2);
    transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);

    &:hover {
      border-color: var(--color-primary-light-3);
      box-shadow: 0 12px 24px 0 var(--color-fill-3);
      transform: translateY(-6px);
    }

    .node-card-inner {
      padding: 20px;
    }

    .node-header-row {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
    }

    .node-identity {
      display: flex;
      gap: 12px;
      align-items: center;

      .node-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 40px;
        height: 40px;
        color: var(--color-primary-6);
        background: var(--color-primary-light-1);
        border-radius: 10px;
      }

      .node-id {
        margin-bottom: 2px;
        color: var(--color-text-1);
        font-weight: 600;
        font-size: 16px;
      }

      .node-addr {
        color: var(--color-text-3);
        font-size: 13px;
        font-family: monospace;
      }
    }

    .metrics-section {
      display: flex;
      flex-direction: column;
      gap: 16px;
      margin-bottom: 24px;
    }

    .metric-group {
      .metric-label-row {
        display: flex;
        justify-content: space-between;
        margin-bottom: 6px;
        font-size: 13px;

        .label {
          color: var(--color-text-2);
        }

        .value {
          color: var(--color-text-1);
          font-weight: 500;
        }
      }

      .premium-progress {
        :deep(.arco-progress-line-bar) {
          height: 8px !important;
          border-radius: 4px;
        }
      }
    }

    .stats-footer {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      margin: 0 -20px -20px;
      padding: 16px 20px;
      background: var(--color-fill-1);
      border-top: 1px solid var(--color-fill-3);

      .stat-item {
        display: flex;
        flex-direction: column;
        gap: 4px;
        align-items: center;

        .stat-value {
          color: var(--color-text-1);
          font-weight: 600;
          font-size: 15px;

          &.uptime {
            color: var(--color-primary-6);
            font-size: 13px;
          }
        }

        .stat-label {
          color: var(--color-text-3);
          font-size: 11px;
          letter-spacing: 0.5px;
          text-transform: uppercase;
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
    margin: 16px 0;
  }
</style>
