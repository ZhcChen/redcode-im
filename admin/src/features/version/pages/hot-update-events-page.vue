<template>
  <div class="hot-update-events-container">
    <Breadcrumb :items="['menu.version', 'menu.version.hotUpdateEvents']" />
    <a-card class="general-card" title="热更新上报" :bordered="false">
      <a-form
        :model="filters"
        layout="inline"
        :gutter="16"
        @submit.prevent="fetchEvents"
      >
        <a-form-item label="平台">
          <a-select v-model="filters.platform" style="width: 140px">
            <a-option value="" label="全部" />
            <a-option :value="AppPlatform.Android" label="Android" />
            <a-option :value="AppPlatform.IOS" label="iOS" />
          </a-select>
        </a-form-item>
        <a-form-item label="渠道">
          <a-input
            v-model="filters.channel"
            placeholder="如 stable"
            style="width: 150px"
          />
        </a-form-item>
        <a-form-item label="事件类型">
          <a-select v-model="filters.eventType" style="width: 150px">
            <a-option value="" label="全部" />
            <a-option
              v-for="type in eventTypes"
              :key="type.value"
              :value="type.value"
            >
              {{ type.label }}
            </a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="客户端类型">
          <a-select v-model="filters.clientType" style="width: 140px">
            <a-option value="" label="全部" />
            <a-option value="desktop" label="桌面端" />
            <a-option value="frontend" label="移动端" />
          </a-select>
        </a-form-item>
        <a-form-item label="触发源">
          <a-select v-model="filters.triggerSource" style="width: 130px">
            <a-option value="" label="全部" />
            <a-option value="manual" label="手动" />
            <a-option value="auto" label="自动" />
            <a-option value="notification" label="通知" />
          </a-select>
        </a-form-item>
        <a-form-item label="网络类型">
          <a-select v-model="filters.networkType" style="width: 130px">
            <a-option value="" label="全部" />
            <a-option value="wifi" label="WiFi" />
            <a-option value="cellular" label="蜂窝网络" />
            <a-option value="ethernet" label="以太网" />
            <a-option value="unknown" label="未知" />
          </a-select>
        </a-form-item>
        <a-form-item label="时间范围">
          <a-range-picker
            v-model="filters.range"
            style="width: 260px"
            allow-clear
          />
        </a-form-item>
        <a-form-item>
          <a-button type="primary" :loading="loading" @click="fetchEvents"
            >查询</a-button
          >
        </a-form-item>
      </a-form>

      <a-table
        :data="events"
        :columns="columns"
        :loading="loading"
        row-key="id"
        :pagination="false"
        class="mt-3"
      >
        <template #platform="{ record }">
          <a-tag>{{
            PlatformLabels[record.platform as AppPlatform] ?? record.platform
          }}</a-tag>
        </template>
        <template #channel="{ record }">
          {{ record.channel ?? '-' }}
        </template>
        <template #client_type="{ record }">
          <a-tag v-if="record.client_type === 'desktop'" color="blue"
            >桌面端</a-tag
          >
          <a-tag v-else-if="record.client_type === 'frontend'" color="green"
            >移动端</a-tag
          >
          <span v-else>{{ record.client_type ?? '-' }}</span>
        </template>
        <template #event_type="{ record }">
          <a-tag :color="eventColor(record.event_type)">{{
            eventLabel(record.event_type)
          }}</a-tag>
        </template>
        <template #trigger_source="{ record }">
          <a-tag v-if="record.trigger_source === 'manual'" color="blue"
            >手动</a-tag
          >
          <a-tag v-else-if="record.trigger_source === 'auto'" color="orange"
            >自动</a-tag
          >
          <a-tag
            v-else-if="record.trigger_source === 'notification'"
            color="purple"
            >通知</a-tag
          >
          <span v-else>{{ record.trigger_source ?? '-' }}</span>
        </template>
        <template #os_version="{ record }">
          <a-tooltip :content="record.os_version || '-'">
            <span
              class="text-truncate"
              style="display: inline-block; max-width: 130px"
            >
              {{ record.os_version ?? '-' }}
            </span>
          </a-tooltip>
        </template>
        <template #app_arch="{ record }">
          <a-tag v-if="record.app_arch" size="small">{{
            record.app_arch
          }}</a-tag>
          <span v-else>-</span>
        </template>
        <template #network_type="{ record }">
          <a-tag
            v-if="record.network_type === 'wifi'"
            color="green"
            size="small"
            >WiFi</a-tag
          >
          <a-tag
            v-else-if="record.network_type === 'cellular'"
            color="blue"
            size="small"
            >蜂窝</a-tag
          >
          <a-tag
            v-else-if="record.network_type === 'ethernet'"
            color="orange"
            size="small"
            >以太网</a-tag
          >
          <span v-else>{{ record.network_type ?? '-' }}</span>
        </template>
        <template #created_at="{ record }">
          {{ formatDate(record.created_at) }}
        </template>
        <template #actions="{ record }">
          <a-button type="text" size="small" @click="showEventDetail(record)">
            详情
          </a-button>
        </template>
      </a-table>

      <!-- 事件详情弹窗 -->
      <a-modal
        v-model:visible="detailModalVisible"
        title="更新事件详情"
        width="800px"
        :footer="false"
      >
        <div v-if="selectedEvent" class="event-detail">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="事件ID">
              <a-typography-text copyable>{{
                selectedEvent.id
              }}</a-typography-text>
            </a-descriptions-item>
            <a-descriptions-item label="时间">
              {{ formatDate(selectedEvent.created_at) }}
            </a-descriptions-item>
            <a-descriptions-item label="平台">
              <a-tag>{{
                PlatformLabels[selectedEvent.platform as AppPlatform] ??
                selectedEvent.platform
              }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="客户端类型">
              <a-tag v-if="selectedEvent.client_type === 'desktop'" color="blue"
                >桌面端</a-tag
              >
              <a-tag
                v-else-if="selectedEvent.client_type === 'frontend'"
                color="green"
                >移动端</a-tag
              >
              <span v-else>{{ selectedEvent.client_type ?? '未知' }}</span>
            </a-descriptions-item>
            <a-descriptions-item label="渠道">
              {{ selectedEvent.channel ?? '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="触发源">
              <a-tag
                v-if="selectedEvent.trigger_source === 'manual'"
                color="blue"
                >手动</a-tag
              >
              <a-tag
                v-else-if="selectedEvent.trigger_source === 'auto'"
                color="orange"
                >自动</a-tag
              >
              <a-tag
                v-else-if="selectedEvent.trigger_source === 'notification'"
                color="purple"
                >通知</a-tag
              >
              <span v-else>{{ selectedEvent.trigger_source ?? '未知' }}</span>
            </a-descriptions-item>
            <a-descriptions-item label="版本信息">
              {{ selectedEvent.base_version }} →
              {{ selectedEvent.patch_version }}
            </a-descriptions-item>
            <a-descriptions-item label="事件类型">
              <a-tag :color="eventColor(selectedEvent.event_type)">
                {{ eventLabel(selectedEvent.event_type) }}
              </a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="操作系统">
              {{ selectedEvent.os_version ?? '未知' }}
            </a-descriptions-item>
            <a-descriptions-item label="架构信息">
              应用: {{ selectedEvent.app_arch ?? '未知' }}<br />
              系统: {{ selectedEvent.os_arch ?? '未知' }}
            </a-descriptions-item>
            <a-descriptions-item label="网络类型">
              <a-tag v-if="selectedEvent.network_type === 'wifi'" color="green"
                >WiFi</a-tag
              >
              <a-tag
                v-else-if="selectedEvent.network_type === 'cellular'"
                color="blue"
                >蜂窝网络</a-tag
              >
              <a-tag
                v-else-if="selectedEvent.network_type === 'ethernet'"
                color="orange"
                >以太网</a-tag
              >
              <span v-else>{{ selectedEvent.network_type ?? '未知' }}</span>
            </a-descriptions-item>
            <a-descriptions-item label="构建号">
              {{ selectedEvent.build_number ?? '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="客户端ID">
              <a-typography-text v-if="selectedEvent.client_id" copyable>
                {{ selectedEvent.client_id }}
              </a-typography-text>
              <span v-else>-</span>
            </a-descriptions-item>
          </a-descriptions>

          <div v-if="selectedEvent.device_info" class="device-info-section">
            <h4>设备详细信息</h4>
            <a-textarea
              :value="formatDeviceInfo(selectedEvent.device_info)"
              readonly
              :auto-size="{ minRows: 3, maxRows: 10 }"
            />
          </div>

          <div v-if="selectedEvent.message" class="message-section">
            <h4>事件消息</h4>
            <a-alert
              :type="
                selectedEvent.event_type.includes('failed') ? 'error' : 'info'
              "
              :message="selectedEvent.message"
              show-icon
            />
          </div>
        </div>
      </a-modal>

      <div v-if="total > 0" class="table-pagination">
        <a-pagination
          :current="pagination.page"
          :page-size="pagination.pageSize"
          :total="total"
          show-total
          @change="handlePageChange"
        />
      </div>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import dayjs from 'dayjs';
  import { reactive, ref, onMounted } from 'vue';
  import { Message, type TableColumnData } from '@arco-design/web-vue';
  import {
    listHotUpdateEvents,
    type HotUpdateEventInfo,
    type ListHotUpdateEventsParams,
  } from '@/services/hot-update';
  import { AppPlatform, PlatformLabels } from '@/services/app-version';

  const loading = ref(false);
  const events = ref<HotUpdateEventInfo[]>([]);
  const total = ref(0);
  const detailModalVisible = ref(false);
  const selectedEvent = ref<HotUpdateEventInfo | null>(null);

  const filters = reactive({
    platform: '' as string,
    channel: '',
    eventType: '',
    range: [] as (string | Date)[],
    clientType: '',
    triggerSource: '',
    networkType: '',
  });

  const pagination = reactive({
    page: 1,
    pageSize: 20,
  });

  const eventTypes = [
    { value: 'download_success', label: '下载成功' },
    { value: 'download_failed', label: '下载失败' },
    { value: 'apply_success', label: '应用成功' },
    { value: 'apply_failed', label: '应用失败' },
    { value: 'rollback', label: '回滚' },
  ];

  const columns: TableColumnData[] = [
    {
      title: '时间',
      dataIndex: 'created_at',
      slotName: 'created_at',
      width: 180,
    },
    { title: '平台', dataIndex: 'platform', slotName: 'platform', width: 100 },
    {
      title: '客户端类型',
      dataIndex: 'client_type',
      slotName: 'client_type',
      width: 120,
    },
    { title: '渠道', dataIndex: 'channel', slotName: 'channel', width: 100 },
    { title: '基线版本', dataIndex: 'base_version', width: 120 },
    { title: '补丁版本', dataIndex: 'patch_version', width: 120 },
    {
      title: '事件',
      dataIndex: 'event_type',
      slotName: 'event_type',
      width: 120,
    },
    {
      title: '触发源',
      dataIndex: 'trigger_source',
      slotName: 'trigger_source',
      width: 100,
    },
    {
      title: '操作系统',
      dataIndex: 'os_version',
      slotName: 'os_version',
      width: 140,
    },
    { title: '架构', dataIndex: 'app_arch', slotName: 'app_arch', width: 100 },
    {
      title: '网络',
      dataIndex: 'network_type',
      slotName: 'network_type',
      width: 100,
    },
    { title: '客户端ID', dataIndex: 'client_id', width: 140 },
    { title: '备注', dataIndex: 'message', ellipsis: true, width: 200 },
    {
      title: '操作',
      dataIndex: 'actions',
      slotName: 'actions',
      width: 80,
      fixed: 'right',
    },
  ];

  const formatDate = (value: string) =>
    dayjs(value).format('YYYY-MM-DD HH:mm:ss');

  const eventLabel = (value: string) => {
    const map: Record<string, string> = {
      download_success: '下载成功',
      download_failed: '下载失败',
      apply_success: '应用成功',
      apply_failed: '应用失败',
      rollback: '回滚',
    };
    return map[value] ?? value;
  };

  const eventColor = (value: string) => {
    switch (value) {
      case 'download_failed':
      case 'apply_failed':
        return 'red';
      case 'rollback':
        return 'orange';
      default:
        return 'green';
    }
  };

  const buildParams = (): ListHotUpdateEventsParams => {
    const params: ListHotUpdateEventsParams = {
      limit: pagination.pageSize,
      offset: (pagination.page - 1) * pagination.pageSize,
    };
    if (filters.platform) params.platform = filters.platform;
    if (filters.channel) params.channel = filters.channel.trim();
    if (filters.eventType) params.event_type = filters.eventType;
    if (filters.clientType) params.client_type = filters.clientType;
    if (filters.triggerSource) params.trigger_source = filters.triggerSource;
    if (filters.networkType) params.network_type = filters.networkType;
    if (filters.range && filters.range.length === 2) {
      params.start_time = dayjs(filters.range[0]).toISOString();
      params.end_time = dayjs(filters.range[1]).toISOString();
    }
    return params;
  };

  const fetchEvents = async () => {
    loading.value = true;
    try {
      const { data } = await listHotUpdateEvents(buildParams());
      events.value = data.items;
      total.value = data.total;
    } catch (error: any) {
      Message.error(
        error?.response?.data?.message || error?.message || '加载失败'
      );
    } finally {
      loading.value = false;
    }
  };

  const handlePageChange = (page: number) => {
    pagination.page = page;
    fetchEvents();
  };

  const showEventDetail = (event: HotUpdateEventInfo) => {
    selectedEvent.value = event;
    detailModalVisible.value = true;
  };

  const formatDeviceInfo = (deviceInfo: string): string => {
    if (!deviceInfo) return '';

    // 将逗号分隔的键值对格式化为更易读的格式
    return deviceInfo
      .split(',')
      .map((pair) => {
        const [key, value] = pair.split(':');
        return `${key}: ${value}`;
      })
      .join('\n');
  };

  onMounted(() => {
    fetchEvents();
  });
</script>

<style scoped>
  .hot-update-events-container {
    padding: 0 20px 20px;
  }

  .mt-3 {
    margin-top: 16px;
  }

  .table-pagination {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }

  .update-form {
    margin-bottom: 16px;
  }

  .text-truncate {
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
  }

  /* 响应式调整 */
  @media (max-width: 1400px) {
    :deep(.arco-table-th),
    :deep(.arco-table-td) {
      padding: 8px 4px;
    }
  }

  /* 表格滚动优化 */
  :deep(.arco-table-container) {
    overflow-x: auto;
  }

  /* 标签样式优化 */
  :deep(.arco-tag) {
    margin: 0;
  }

  /* 详情弹窗样式 */
  .event-detail {
    /* 分开定义,避免 CSS 压缩器警告 */
    .device-info-section {
      margin-top: 20px;

      h4 {
        margin-bottom: 8px;
        color: rgb(var(--arcoblue-6));
        font-weight: 500;
      }

      :deep(.arco-textarea) {
        font-size: 12px;
        font-family: Monaco, Menlo, 'Ubuntu Mono', monospace;
        line-height: 1.5;
      }
    }

    .message-section {
      margin-top: 20px;

      h4 {
        margin-bottom: 8px;
        color: rgb(var(--arcoblue-6));
        font-weight: 500;
      }

      :deep(.arco-alert) {
        margin-bottom: 0;
      }
    }
  }

  /* 描述列表样式优化 */
  :deep(.arco-descriptions-item-label) {
    color: rgb(var(--gray-8));
    font-weight: 500;
  }

  :deep(.arco-descriptions-item-content) {
    word-break: break-word;
  }
</style>
