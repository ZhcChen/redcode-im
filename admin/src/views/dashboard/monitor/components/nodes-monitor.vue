<template>
  <a-card class="nodes-monitor" title="集群节点监控" :bordered="false">
    <template #extra>
      <a-button type="text" @click="fetchData">
        <template #icon><icon-refresh /></template>
        刷新
      </a-button>
    </template>
    <a-spin :loading="loading" style="width: 100%">
      <div v-if="nodes.length === 0" class="empty-status">
        <a-empty description="暂无活跃节点" />
      </div>
      <div v-else class="nodes-grid">
        <a-card
          v-for="node in nodes"
          :key="node.nodeId"
          class="node-card"
          hoverable
        >
          <template #title>
            <a-space>
              <icon-computer />
              <span>{{ node.nodeId }}</span>
              <a-tag size="small" color="green">Active</a-tag>
            </a-space>
          </template>
          <a-descriptions :column="1" size="small">
            <a-descriptions-item label="地址">{{
              node.address
            }}</a-descriptions-item>
            <a-descriptions-item label="核心指标">
              <div class="metrics-grid">
                <div class="metric-item">
                  <div class="metric-label">CPU</div>
                  <a-progress
                    type="circle"
                    size="mini"
                    :percent="Math.round(node.cpuUsage * 100)"
                    :status="getUsageStatus(node.cpuUsage)"
                  />
                </div>
                <div class="metric-item">
                  <div class="metric-label">内存</div>
                  <a-progress
                    type="circle"
                    size="mini"
                    :percent="Math.round(node.memoryUsage * 100)"
                    :status="getUsageStatus(node.memoryUsage)"
                  />
                </div>
                <div class="metric-item">
                  <div class="metric-label">磁盘</div>
                  <a-progress
                    type="circle"
                    size="mini"
                    :percent="Math.round(node.diskUsage * 100)"
                    :status="getUsageStatus(node.diskUsage)"
                  />
                </div>
              </div>
            </a-descriptions-item>
            <a-descriptions-item label="运行状态">
              <a-space :size="20">
                <a-statistic title="连接用户" :value="node.connectedUsers" />
                <a-statistic title="活跃房间" :value="node.activeRooms" />
              </a-space>
            </a-descriptions-item>
            <a-descriptions-item label="最后心跳">
              {{ formatDate(node.lastHeartbeat) }}
            </a-descriptions-item>
          </a-descriptions>
        </a-card>
      </div>
    </a-spin>
  </a-card>
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
      setLoading(false);
    }
  };

  const getUsageStatus = (usage: number) => {
    if (usage > 0.8) return 'danger';
    if (usage > 0.6) return 'warning';
    return 'success';
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
  .nodes-monitor {
    .nodes-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 16px;
    }

    .node-card {
      background-color: var(--color-fill-1);
      border: 1px solid var(--color-border-1);
      transition: all 0.2s;

      &:hover {
        box-shadow: 0 4px 10px rgb(0 0 0 / 10%);
        transform: translateY(-2px);
      }
    }

    .metrics-grid {
      display: flex;
      justify-content: space-around;
      padding: 8px 0;
    }

    .metric-item {
      display: flex;
      flex-direction: column;
      gap: 8px;
      align-items: center;
    }

    .metric-label {
      color: var(--color-text-3);
      font-size: 12px;
    }

    .empty-status {
      padding: 40px 0;
    }
  }
</style>
