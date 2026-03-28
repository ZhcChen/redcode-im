<template>
  <div class="push-log-container">
    <Breadcrumb :items="['menu.operations', 'menu.operations.pushLog']" />
    <a-card
      class="general-card"
      :title="$t('menu.operations.pushLog')"
      :bordered="false"
    >
      <div class="header-actions">
        <a-space wrap>
          <a-input
            v-model="queryParams.pushId"
            :placeholder="t('pushLog.filters.pushId.placeholder')"
            style="width: 220px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.userId"
            :placeholder="t('pushLog.filters.userId.placeholder')"
            style="width: 220px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.deviceId"
            :placeholder="t('pushLog.filters.deviceId.placeholder')"
            style="width: 220px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.provider"
            :placeholder="t('pushLog.filters.provider.placeholder')"
            style="width: 160px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.eventType"
            :placeholder="t('pushLog.filters.eventType.placeholder')"
            style="width: 180px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-select
            v-model="queryParams.success"
            :placeholder="t('pushLog.filters.success.placeholder')"
            style="width: 120px"
            allow-clear
            @change="handleSearch"
          >
            <a-option :value="true">
              {{ t('pushLog.filters.success.true') }}
            </a-option>
            <a-option :value="false">
              {{ t('pushLog.filters.success.false') }}
            </a-option>
          </a-select>
          <a-input
            v-model="queryParams.keyword"
            :placeholder="t('pushLog.filters.keyword.placeholder')"
            style="width: 240px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-range-picker
            v-model="timeRange"
            show-time
            style="width: 360px"
            @change="handleSearch"
          />
          <a-button type="primary" @click="handleSearch">
            <template #icon><icon-search /></template>
            {{ t('pushLog.actions.search') }}
          </a-button>
          <a-button @click="handleReset">{{ t('pushLog.actions.reset') }}</a-button>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            {{ t('pushLog.actions.refresh') }}
          </a-button>
          <a-button type="outline" status="danger" @click="handleOpenCleanup">
            <template #icon><icon-delete /></template>
            {{ t('pushLog.actions.cleanup') }}
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="logList"
        :columns="columns"
        :pagination="pagination"
        :loading="loading"
        row-key="id"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #createdAt="{ record }">
          {{ formatDate(record.createdAt) }}
        </template>
        <template #success="{ record }">
          <a-tag :color="record.success ? 'green' : 'red'">
            {{
              record.success
                ? t('pushLog.status.success')
                : t('pushLog.status.failed')
            }}
          </a-tag>
        </template>
        <template #user="{ record }">
          <div class="user-cell">
            <div v-if="record.username || record.nickname">
              <span class="user-name">
                {{ record.nickname || record.username }}
              </span>
              <span v-if="record.username && record.nickname" class="user-sub"
                >({{ record.username }})</span
              >
            </div>
            <div class="user-sub">{{ record.userId }}</div>
          </div>
        </template>
        <template #title="{ record }">
          <div class="ellipsis-cell" :title="record.title || '-'">
            {{ record.title || '-' }}
          </div>
        </template>
        <template #error="{ record }">
          <div class="ellipsis-cell error-cell" :title="record.error || '-'">
            {{ record.error || '-' }}
          </div>
        </template>
        <template #actions="{ record }">
          <a-button type="text" size="small" @click="handleViewDetail(record)">
            {{ t('pushLog.actions.viewDetail') }}
          </a-button>
        </template>
      </a-table>
    </a-card>

    <a-drawer
      v-model:visible="drawerVisible"
      :title="t('pushLog.drawer.title')"
      width="720px"
      unmount-on-close
    >
      <div v-if="selectedLog" class="log-detail">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item :label="t('pushLog.detail.id')">
            <a-typography-text copyable>{{ selectedLog.id }}</a-typography-text>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.pushId')">
            <a-typography-text copyable>{{
              selectedLog.pushId
            }}</a-typography-text>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.time')">
            {{ formatDate(selectedLog.createdAt) }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.result')">
            <a-tag :color="selectedLog.success ? 'green' : 'red'">
              {{
                selectedLog.success
                  ? t('pushLog.status.success')
                  : t('pushLog.status.failed')
              }}
            </a-tag>
            <span class="attempt-text">attempt={{ selectedLog.attempt }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.user')">
            <a-typography-text copyable>{{
              selectedLog.userId
            }}</a-typography-text>
            <span v-if="selectedLog.username" class="user-sub"
              >（{{ selectedLog.username }}）</span
            >
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.deviceId')">
            <a-typography-text copyable>{{
              selectedLog.deviceId
            }}</a-typography-text>
          </a-descriptions-item>
          <a-descriptions-item
            :label="t('pushLog.detail.platformChannelProvider')"
          >
            {{ selectedLog.platform }} / {{ selectedLog.channel }} /
            {{ selectedLog.provider }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.eventType')">
            {{ selectedLog.eventType }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.roomId')">
            <a-typography-text v-if="selectedLog.roomId" copyable>{{
              selectedLog.roomId
            }}</a-typography-text>
            <span v-else>-</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.messageId')">
            <a-typography-text v-if="selectedLog.messageId" copyable>{{
              selectedLog.messageId
            }}</a-typography-text>
            <span v-else>-</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.requestId')">
            <a-typography-text v-if="selectedLog.requestId" copyable>{{
              selectedLog.requestId
            }}</a-typography-text>
            <span v-else>-</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.title')">
            {{ selectedLog.title || '-' }}
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.body')">
            <pre class="text-display">{{ selectedLog.body || '-' }}</pre>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.error')">
            <pre class="text-display">{{ selectedLog.error || '-' }}</pre>
          </a-descriptions-item>
          <a-descriptions-item :label="t('pushLog.detail.payload')">
            <pre class="json-display">{{ formatJson(selectedLog.data) }}</pre>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-drawer>

    <a-modal
      v-model:visible="cleanupVisible"
      :title="t('pushLog.cleanup.title')"
      @ok="handleCleanup"
    >
      <a-form :model="cleanupForm">
        <a-form-item
          :label="t('pushLog.cleanup.retentionDays.label')"
          :help="t('pushLog.cleanup.retentionDays.help')"
        >
          <a-input-number v-model="cleanupForm.retentionDays" :min="1" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted, computed } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import {
    queryPushLogs,
    cleanupPushLogs,
    type PushLogEntry,
    type PushLogQueryParams,
  } from '@/api/push-log';

  const { t } = useI18n();
  const { loading, setLoading } = useLoading(true);
  const logList = ref<PushLogEntry[]>([]);
  const drawerVisible = ref(false);
  const selectedLog = ref<PushLogEntry | null>(null);
  const cleanupVisible = ref(false);
  const timeRange = ref<[string, string] | []>([]);

  const queryParams = reactive<PushLogQueryParams>({
    pushId: '',
    userId: '',
    deviceId: '',
    provider: '',
    eventType: '',
    keyword: '',
    success: undefined,
    startTime: undefined,
    endTime: undefined,
  });

  const pagination = reactive({
    current: 1,
    pageSize: 50,
    total: 0,
    showTotal: true,
    showJumper: true,
    pageSizeOptions: [20, 50, 100, 200, 500],
  });

  const cleanupForm = reactive({
    retentionDays: 7,
  });

  const columns = computed(() => [
    {
      title: t('pushLog.table.time'),
      dataIndex: 'createdAt',
      slotName: 'createdAt',
      width: 180,
    },
    {
      title: t('pushLog.table.eventType'),
      dataIndex: 'eventType',
      width: 140,
    },
    {
      title: t('pushLog.table.user'),
      slotName: 'user',
      width: 240,
    },
    {
      title: t('pushLog.table.platform'),
      dataIndex: 'platform',
      width: 100,
    },
    {
      title: t('pushLog.table.channel'),
      dataIndex: 'channel',
      width: 100,
    },
    {
      title: t('pushLog.table.provider'),
      dataIndex: 'provider',
      width: 100,
    },
    {
      title: t('pushLog.table.result'),
      slotName: 'success',
      width: 80,
    },
    {
      title: t('pushLog.table.title'),
      dataIndex: 'title',
      slotName: 'title',
      ellipsis: true,
      tooltip: true,
      minWidth: 200,
    },
    {
      title: t('pushLog.table.error'),
      dataIndex: 'error',
      slotName: 'error',
      ellipsis: true,
      tooltip: true,
      minWidth: 200,
    },
    {
      title: t('pushLog.table.actions'),
      slotName: 'actions',
      width: 100,
      fixed: 'right',
    },
  ]);

  const formatDate = (date: string) => {
    return dayjs(date).format('YYYY-MM-DD HH:mm:ss');
  };

  const formatJson = (json: any) => {
    try {
      return JSON.stringify(json, null, 2);
    } catch (e) {
      return String(json);
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const params: PushLogQueryParams = {
        ...queryParams,
        limit: pagination.pageSize,
        offset: (pagination.current - 1) * pagination.pageSize,
      };

      if (timeRange.value && timeRange.value.length === 2) {
        params.startTime = dayjs(timeRange.value[0]).toISOString();
        params.endTime = dayjs(timeRange.value[1]).toISOString();
      } else {
        params.startTime = undefined;
        params.endTime = undefined;
      }

      const { data } = await queryPushLogs(params);
      if (data) {
        logList.value = data.logs;
        pagination.total = data.total;
      }
    } catch (error) {
      Message.error(t('pushLog.messages.fetchError'));
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    pagination.current = 1;
    fetchData();
  };

  const handleReset = () => {
    queryParams.pushId = '';
    queryParams.userId = '';
    queryParams.deviceId = '';
    queryParams.provider = '';
    queryParams.eventType = '';
    queryParams.keyword = '';
    queryParams.success = undefined;
    timeRange.value = [];
    handleSearch();
  };

  const handleRefresh = () => {
    fetchData();
  };

  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchData();
  };

  const handlePageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    pagination.current = 1;
    fetchData();
  };

  const handleViewDetail = (record: PushLogEntry) => {
    selectedLog.value = record;
    drawerVisible.value = true;
  };

  const handleOpenCleanup = () => {
    cleanupVisible.value = true;
  };

  const handleCleanup = async () => {
    try {
      const { data } = await cleanupPushLogs({
        retentionDays: cleanupForm.retentionDays,
      });
      if (data.success) {
        Message.success(data.message);
        fetchData();
      } else {
        Message.error(data.message);
      }
    } catch (error) {
      Message.error(t('pushLog.messages.cleanupError'));
    }
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .push-log-container {
    padding: 0 20px 20px;

    .general-card {
      .header-actions {
        margin-bottom: 16px;
      }
    }

    .ellipsis-cell {
      overflow: hidden;
      white-space: nowrap;
      text-overflow: ellipsis;
    }

    .error-cell {
      color: rgb(var(--red-6));
    }

    .user-cell {
      .user-name {
        font-weight: 500;
      }

      .user-sub {
        margin-left: 6px;
        color: var(--color-text-3);
        font-size: 12px;
      }
    }

    .attempt-text {
      margin-left: 8px;
      color: var(--color-text-3);
    }

    .json-display {
      max-height: 400px;
      margin: 0;
      padding: 8px;
      overflow-y: auto;
      font-size: 12px;
      font-family: monospace;
      background-color: var(--color-fill-1);
      border-radius: 4px;
    }

    .text-display {
      max-height: 120px;
      margin: 0;
      padding: 8px;
      overflow-y: auto;
      font-size: 12px;
      font-family: monospace;
      white-space: pre-wrap;
      word-break: break-word;
      background-color: var(--color-fill-1);
      border-radius: 4px;
    }
  }
</style>
