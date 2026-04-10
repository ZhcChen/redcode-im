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
            placeholder="日志级别"
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
            placeholder="模块路径"
            style="width: 180px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.keyword"
            placeholder="关键词搜索"
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
            查询
          </a-button>
          <a-button @click="handleReset"> 重置 </a-button>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
          <a-button type="outline" status="danger" @click="handleOpenCleanup">
            <template #icon><icon-delete /></template>
            清理日志
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
            详情
          </a-button>
        </template>
      </a-table>
    </a-card>

    <!-- 详情抽屉 -->
    <a-drawer
      v-model:visible="drawerVisible"
      title="日志详情"
      width="600px"
      unmount-on-close
    >
      <div v-if="selectedLog" class="log-detail">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="ID">{{
            selectedLog.id
          }}</a-descriptions-item>
          <a-descriptions-item label="级别">
            <a-tag :color="getLevelColor(selectedLog.level)">{{
              selectedLog.level
            }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="时间">{{
            formatDate(selectedLog.createdAt)
          }}</a-descriptions-item>
          <a-descriptions-item label="模块">{{
            selectedLog.target
          }}</a-descriptions-item>
          <a-descriptions-item label="节点 ID">{{
            selectedLog.nodeId
          }}</a-descriptions-item>
          <a-descriptions-item label="消息">{{
            selectedLog.message
          }}</a-descriptions-item>
          <a-descriptions-item label="扩展字段">
            <pre class="json-display">{{ formatJson(selectedLog.fields) }}</pre>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-drawer>

    <!-- 清理弹窗 -->
    <a-modal
      v-model:visible="cleanupVisible"
      title="清理系统日志"
      @ok="handleCleanup"
    >
      <a-form :model="cleanupForm">
        <a-form-item label="保留天数" help="将删除早于此天数的所有日志">
          <a-input-number v-model="cleanupForm.retentionDays" :min="1" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import useLoading from '@/hooks/loading';
  import {
    querySystemLogs,
    cleanupSystemLogs,
    type SystemLogEntry,
    type SystemLogQueryParams,
  } from '@/api/system-log';

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

  const columns = [
    {
      title: '级别',
      dataIndex: 'level',
      slotName: 'level',
      width: 100,
    },
    {
      title: '时间',
      dataIndex: 'createdAt',
      slotName: 'createdAt',
      width: 180,
    },
    {
      title: '模块',
      dataIndex: 'target',
      width: 200,
    },
    {
      title: '消息',
      dataIndex: 'message',
      slotName: 'message',
      ellipsis: true,
      tooltip: true,
    },
    {
      title: '节点',
      dataIndex: 'nodeId',
      width: 120,
    },
    {
      title: '操作',
      slotName: 'actions',
      width: 100,
      fixed: 'right',
    },
  ];

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
      Message.error('获取日志列表失败');
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
      Message.error('清理日志失败');
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
