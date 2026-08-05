<template>
  <div class="file-upload-audit-container">
    <Breadcrumb
      :items="['menu.operations', 'menu.operations.fileUploadAudit']"
    />
    <a-card
      class="general-card"
      :title="$t('menu.operations.fileUploadAudit')"
      :bordered="false"
    >
      <div class="header-actions">
        <a-space wrap>
          <a-select
            v-model="queryParams.status"
            placeholder="状态"
            style="width: 140px"
            allow-clear
            @change="handleSearch"
          >
            <a-option :value="0">待处理</a-option>
            <a-option :value="1">通过</a-option>
            <a-option :value="2">拒绝</a-option>
            <a-option :value="3">重试中</a-option>
            <a-option :value="4">失败</a-option>
          </a-select>
          <a-select
            v-model="queryParams.mediaKind"
            placeholder="媒体类型"
            style="width: 140px"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="image">image</a-option>
            <a-option value="video">video</a-option>
            <a-option value="audio">audio</a-option>
            <a-option value="text">text</a-option>
            <a-option value="document">document</a-option>
            <a-option value="unknown">unknown</a-option>
          </a-select>
          <a-input
            v-model="queryParams.scene"
            placeholder="场景（scene）"
            style="width: 160px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.providerId"
            placeholder="Provider ID"
            style="width: 220px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.keyword"
            placeholder="Object Key 关键词"
            style="width: 220px"
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
          <a-button @click="handleReset">重置</a-button>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="taskList"
        :columns="columns"
        :pagination="pagination"
        :loading="loading"
        row-key="id"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #objectKey="{ record }">
          <div class="ellipsis-cell" :title="record.objectKey">
            {{ record.objectKey }}
          </div>
        </template>
        <template #lastError="{ record }">
          <div class="ellipsis-cell" :title="record.lastError">
            {{ record.lastError || '-' }}
          </div>
        </template>
        <template #createdAt="{ record }">
          {{ formatDate(record.createdAt) }}
        </template>
        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleViewDetail(record)"
            >
              详情
            </a-button>
            <a-button
              type="text"
              size="small"
              status="warning"
              @click="handleRequeue(record)"
            >
              重新入队
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <a-drawer
      v-model:visible="drawerVisible"
      title="审核任务详情"
      width="720px"
      unmount-on-close
    >
      <div v-if="selectedTask" class="task-detail">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="ID">{{
            selectedTask.id
          }}</a-descriptions-item>
          <a-descriptions-item label="Provider ID">{{
            selectedTask.storageProviderId
          }}</a-descriptions-item>
          <a-descriptions-item label="Object Key">{{
            selectedTask.objectKey
          }}</a-descriptions-item>
          <a-descriptions-item label="场景">{{
            selectedTask.scene
          }}</a-descriptions-item>
          <a-descriptions-item label="媒体类型">{{
            selectedTask.mediaKind
          }}</a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="getStatusColor(selectedTask.status)">{{
              getStatusText(selectedTask.status)
            }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="Content-Type">{{
            selectedTask.contentType || '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="File Size">{{
            selectedTask.fileSize ?? '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="Vendor JobId">{{
            selectedTask.vendorJobId || '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="Attempts">{{
            selectedTask.attempts
          }}</a-descriptions-item>
          <a-descriptions-item label="Next Run">{{
            formatDate(selectedTask.nextRunAt)
          }}</a-descriptions-item>
          <a-descriptions-item label="Audited At">{{
            selectedTask.auditedAt ? formatDate(selectedTask.auditedAt) : '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="Rejected Reason">{{
            selectedTask.rejectedReason || '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="Last Error">{{
            selectedTask.lastError || '-'
          }}</a-descriptions-item>
          <a-descriptions-item label="Created At">{{
            formatDate(selectedTask.createdAt)
          }}</a-descriptions-item>
          <a-descriptions-item label="Updated At">{{
            formatDate(selectedTask.updatedAt)
          }}</a-descriptions-item>
          <a-descriptions-item label="Result">
            <pre class="json-display">{{
              formatJson(selectedTask.result)
            }}</pre>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-drawer>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { Message, Modal, type TableColumnData } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import useLoading from '@/hooks/loading';
  import {
    queryFileUploadAuditTasks,
    getFileUploadAuditTask,
    requeueFileUploadAuditTask,
    type FileUploadAuditTaskListEntry,
    type FileUploadAuditTaskQueryParams,
    type FileUploadAuditTaskDetailEntry,
  } from '@/services/file-upload-audit';

  const { loading, setLoading } = useLoading(true);
  const taskList = ref<FileUploadAuditTaskListEntry[]>([]);
  const drawerVisible = ref(false);
  const selectedTask = ref<FileUploadAuditTaskDetailEntry | null>(null);
  const timeRange = ref<[string, string] | []>([]);

  const queryParams = reactive<FileUploadAuditTaskQueryParams>({
    providerId: '',
    status: undefined,
    scene: '',
    mediaKind: '',
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

  const columns: TableColumnData[] = [
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 110 },
    { title: '场景', dataIndex: 'scene', width: 140 },
    { title: '媒体', dataIndex: 'mediaKind', width: 110 },
    { title: 'Object Key', dataIndex: 'objectKey', slotName: 'objectKey' },
    {
      title: 'Provider',
      dataIndex: 'storageProviderId',
      width: 230,
    },
    { title: '重试次数', dataIndex: 'attempts', width: 90 },
    { title: '错误', dataIndex: 'lastError', slotName: 'lastError' },
    {
      title: '创建时间',
      dataIndex: 'createdAt',
      slotName: 'createdAt',
      width: 180,
    },
    { title: '操作', slotName: 'actions', width: 160, fixed: 'right' },
  ];

  const formatDate = (date: string) =>
    dayjs(date).format('YYYY-MM-DD HH:mm:ss');

  const formatJson = (json: any) => {
    try {
      return JSON.stringify(json, null, 2);
    } catch (e) {
      return String(json);
    }
  };

  const getStatusText = (status: number) => {
    switch (status) {
      case 0:
        return '待处理';
      case 1:
        return '通过';
      case 2:
        return '拒绝';
      case 3:
        return '重试中';
      case 4:
        return '失败';
      default:
        return String(status);
    }
  };

  const getStatusColor = (status: number) => {
    switch (status) {
      case 0:
        return 'gray';
      case 1:
        return 'green';
      case 2:
        return 'red';
      case 3:
        return 'orange';
      case 4:
        return 'red';
      default:
        return 'gray';
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const params: FileUploadAuditTaskQueryParams = {
        providerId: queryParams.providerId || undefined,
        status: queryParams.status,
        scene: queryParams.scene || undefined,
        mediaKind: queryParams.mediaKind || undefined,
        keyword: queryParams.keyword || undefined,
        limit: pagination.pageSize,
        offset: (pagination.current - 1) * pagination.pageSize,
      };

      if (timeRange.value && timeRange.value.length === 2) {
        params.startTime = dayjs(timeRange.value[0]).toISOString();
        params.endTime = dayjs(timeRange.value[1]).toISOString();
      }

      const { data } = await queryFileUploadAuditTasks(params);
      taskList.value = data?.tasks || [];
      pagination.total = data?.total || 0;
    } catch (e: any) {
      Message.error(e?.message || '加载审核任务失败');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    pagination.current = 1;
    fetchData();
  };

  const handleReset = () => {
    queryParams.providerId = '';
    queryParams.status = undefined;
    queryParams.scene = '';
    queryParams.mediaKind = '';
    queryParams.keyword = '';
    timeRange.value = [];
    pagination.current = 1;
    fetchData();
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

  const handleViewDetail = async (record: FileUploadAuditTaskListEntry) => {
    setLoading(true);
    try {
      const { data } = await getFileUploadAuditTask(record.id);
      selectedTask.value = data.task;
      drawerVisible.value = true;
    } catch (e: any) {
      Message.error(e?.message || '加载详情失败');
    } finally {
      setLoading(false);
    }
  };

  const handleRequeue = (record: FileUploadAuditTaskListEntry) => {
    Modal.confirm({
      title: '重新入队',
      content: `确认将任务重新入队？\n${record.objectKey}`,
      async onOk() {
        try {
          const { data } = await requeueFileUploadAuditTask(record.id);
          if (data?.success) {
            Message.success(data.message || '已重新入队');
            fetchData();
          } else {
            Message.error(data?.message || '操作失败');
          }
        } catch (e: any) {
          Message.error(e?.message || '操作失败');
        }
      },
    });
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style scoped>
  .file-upload-audit-container {
    padding: 16px;
  }

  .header-actions {
    margin-bottom: 16px;
  }

  .ellipsis-cell {
    max-width: 520px;
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
  }

  .json-display {
    margin: 0;
    padding: 12px;
    overflow: auto;
    font-size: 12px;
    line-height: 1.5;
    background: #f7f8fa;
    border-radius: 6px;
  }
</style>
