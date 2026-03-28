<template>
  <div class="system-log-container">
    <Breadcrumb :items="['menu.operations', 'menu.operations.systemLog']" />
    <a-card
      class="general-card"
      :title="$t('menu.operations.systemLog')"
      :bordered="false"
    >
      <div class="header-actions">
        <a-space wrap>
          <a-select
            v-model="queryParams.level"
            :placeholder="t('systemLog.filters.level.placeholder')"
            style="width: 120px"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="DEBUG">DEBUG</a-option>
            <a-option value="INFO">INFO</a-option>
            <a-option value="WARN">WARN</a-option>
            <a-option value="ERROR">ERROR</a-option>
          </a-select>
          <a-input
            v-model="queryParams.target"
            :placeholder="t('systemLog.filters.target.placeholder')"
            style="width: 180px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.keyword"
            :placeholder="t('systemLog.filters.keyword.placeholder')"
            style="width: 180px"
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
            {{ t('systemLog.actions.search') }}
          </a-button>
          <a-button @click="handleReset">
            {{ t('systemLog.actions.reset') }}
          </a-button>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            {{ t('systemLog.actions.refresh') }}
          </a-button>
          <a-button type="outline" status="danger" @click="handleOpenCleanup">
            <template #icon><icon-delete /></template>
            {{ t('systemLog.actions.cleanup') }}
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
        <template #level="{ record }">
          <a-tag :color="getLevelColor(record.level)">
            {{ record.level }}
          </a-tag>
        </template>
        <template #message="{ record }">
          <div class="log-message-cell" :title="record.message">
            {{ record.message }}
          </div>
        </template>
        <template #createdAt="{ record }">
          {{ formatDate(record.createdAt) }}
        </template>
        <template #actions="{ record }">
          <a-button type="text" size="small" @click="handleViewDetail(record)">
            {{ t('systemLog.actions.viewDetail') }}
          </a-button>
        </template>
      </a-table>
    </a-card>

    <a-drawer
      v-model:visible="drawerVisible"
      :title="t('systemLog.drawer.title')"
      width="600px"
      unmount-on-close
    >
      <div v-if="selectedLog" class="log-detail">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item :label="t('systemLog.detail.id')">{{
            selectedLog.id
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.level')">
            <a-tag :color="getLevelColor(selectedLog.level)">{{
              selectedLog.level
            }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.time')">{{
            formatDate(selectedLog.createdAt)
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.target')">{{
            selectedLog.target
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.nodeId')">{{
            selectedLog.nodeId
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.message')">{{
            selectedLog.message
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('systemLog.detail.fields')">
            <pre class="json-display">{{ formatJson(selectedLog.fields) }}</pre>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-drawer>

    <a-modal
      v-model:visible="cleanupVisible"
      :title="t('systemLog.cleanup.title')"
      @ok="handleCleanup"
    >
      <a-form :model="cleanupForm">
        <a-form-item
          :label="t('systemLog.cleanup.retentionDays.label')"
          :help="t('systemLog.cleanup.retentionDays.help')"
        >
          <a-input-number v-model="cleanupForm.retentionDays" :min="1" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted, computed } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import {
    querySystemLogs,
    cleanupSystemLogs,
    type SystemLogEntry,
    type SystemLogQueryParams,
  } from '@/api/system-log';

  const { t } = useI18n();
  const { loading, setLoading } = useLoading(true);
  const logList = ref<SystemLogEntry[]>([]);
  const drawerVisible = ref(false);
  const selectedLog = ref<SystemLogEntry | null>(null);
  const cleanupVisible = ref(false);
  const timeRange = ref<[string, string] | []>([]);

  const queryParams = reactive<SystemLogQueryParams>({
    level: undefined,
    target: '',
    keyword: '',
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
      title: t('systemLog.table.level'),
      dataIndex: 'level',
      slotName: 'level',
      width: 100,
    },
    {
      title: t('systemLog.table.time'),
      dataIndex: 'createdAt',
      slotName: 'createdAt',
      width: 180,
    },
    {
      title: t('systemLog.table.target'),
      dataIndex: 'target',
      width: 200,
    },
    {
      title: t('systemLog.table.message'),
      dataIndex: 'message',
      slotName: 'message',
      ellipsis: true,
      tooltip: true,
    },
    {
      title: t('systemLog.table.nodeId'),
      dataIndex: 'nodeId',
      width: 120,
    },
    {
      title: t('systemLog.table.actions'),
      slotName: 'actions',
      width: 100,
      fixed: 'right',
    },
  ]);

  const getLevelColor = (level: string) => {
    switch (level) {
      case 'DEBUG':
        return 'gray';
      case 'INFO':
        return 'blue';
      case 'WARN':
        return 'orange';
      case 'ERROR':
        return 'red';
      default:
        return 'gray';
    }
  };

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
      const params: SystemLogQueryParams = {
        ...queryParams,
        limit: pagination.pageSize,
        offset: (pagination.current - 1) * pagination.pageSize,
      };

      if (timeRange.value && timeRange.value.length === 2) {
        params.startTime = dayjs(timeRange.value[0]).toISOString();
        params.endTime = dayjs(timeRange.value[1]).toISOString();
      }

      const { data } = await querySystemLogs(params);
      if (data) {
        logList.value = data.logs;
        pagination.total = data.total;
      }
    } catch (error: any) {
      Message.error(t('systemLog.messages.fetchError'));
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    pagination.current = 1;
    fetchData();
  };

  const handleReset = () => {
    queryParams.level = undefined;
    queryParams.target = '';
    queryParams.keyword = '';
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

  const handleViewDetail = (record: SystemLogEntry) => {
    selectedLog.value = record;
    drawerVisible.value = true;
  };

  const handleOpenCleanup = () => {
    cleanupVisible.value = true;
  };

  const handleCleanup = async () => {
    try {
      const { data } = await cleanupSystemLogs({
        retentionDays: cleanupForm.retentionDays,
      });
      if (data.success) {
        Message.success(data.message);
        fetchData();
      } else {
        Message.error(data.message);
      }
    } catch (error) {
      Message.error(t('systemLog.messages.cleanupError'));
    }
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .system-log-container {
    padding: 0 20px 20px;

    .general-card {
      .header-actions {
        margin-bottom: 16px;
      }
    }

    .log-message-cell {
      overflow: hidden;
      white-space: nowrap;
      text-overflow: ellipsis;
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
  }
</style>
