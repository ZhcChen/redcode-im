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
            :placeholder="t('fileUploadAudit.filters.status.placeholder')"
            style="width: 140px"
            allow-clear
            @change="handleSearch"
          >
            <a-option :value="0">
              {{ t('fileUploadAudit.filters.status.pending') }}
            </a-option>
            <a-option :value="1">
              {{ t('fileUploadAudit.filters.status.approved') }}
            </a-option>
            <a-option :value="2">
              {{ t('fileUploadAudit.filters.status.rejected') }}
            </a-option>
            <a-option :value="3">
              {{ t('fileUploadAudit.filters.status.retrying') }}
            </a-option>
            <a-option :value="4">
              {{ t('fileUploadAudit.filters.status.failed') }}
            </a-option>
          </a-select>
          <a-select
            v-model="queryParams.mediaKind"
            :placeholder="t('fileUploadAudit.filters.mediaKind.placeholder')"
            style="width: 140px"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="image">
              {{ t('fileUploadAudit.filters.mediaKind.image') }}
            </a-option>
            <a-option value="video">
              {{ t('fileUploadAudit.filters.mediaKind.video') }}
            </a-option>
            <a-option value="audio">
              {{ t('fileUploadAudit.filters.mediaKind.audio') }}
            </a-option>
            <a-option value="text">
              {{ t('fileUploadAudit.filters.mediaKind.text') }}
            </a-option>
            <a-option value="document">
              {{ t('fileUploadAudit.filters.mediaKind.document') }}
            </a-option>
            <a-option value="unknown">
              {{ t('fileUploadAudit.filters.mediaKind.unknown') }}
            </a-option>
          </a-select>
          <a-input
            v-model="queryParams.scene"
            :placeholder="t('fileUploadAudit.filters.scene.placeholder')"
            style="width: 160px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.providerId"
            :placeholder="t('fileUploadAudit.filters.providerId.placeholder')"
            style="width: 220px"
            allow-clear
            @press-enter="handleSearch"
          />
          <a-input
            v-model="queryParams.keyword"
            :placeholder="t('fileUploadAudit.filters.keyword.placeholder')"
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
            {{ t('fileUploadAudit.actions.search') }}
          </a-button>
          <a-button @click="handleReset">
            {{ t('fileUploadAudit.actions.reset') }}
          </a-button>
          <a-button @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            {{ t('fileUploadAudit.actions.refresh') }}
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
        <template #mediaKind="{ record }">
          {{ getMediaKindText(record.mediaKind) }}
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
              {{ t('fileUploadAudit.actions.viewDetail') }}
            </a-button>
            <a-button
              type="text"
              size="small"
              status="warning"
              @click="handleRequeue(record)"
            >
              {{ t('fileUploadAudit.actions.requeue') }}
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <a-drawer
      v-model:visible="drawerVisible"
      :title="t('fileUploadAudit.drawer.title')"
      width="720px"
      unmount-on-close
    >
      <div v-if="selectedTask" class="task-detail">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item :label="t('fileUploadAudit.detail.id')">{{
            selectedTask.id
          }}</a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.providerId')"
          >{{
            selectedTask.storageProviderId
          }}</a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.objectKey')"
          >{{
            selectedTask.objectKey
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.scene')">{{
            selectedTask.scene
          }}</a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.mediaKind')"
          >{{
            getMediaKindText(selectedTask.mediaKind)
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.status')">
            <a-tag :color="getStatusColor(selectedTask.status)">{{
              getStatusText(selectedTask.status)
            }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.contentType')"
          >{{
            selectedTask.contentType || '-'
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.fileSize')">{{
            selectedTask.fileSize ?? '-'
          }}</a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.vendorJobId')"
          >{{
            selectedTask.vendorJobId || '-'
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.attempts')">{{
            selectedTask.attempts
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.nextRun')">{{
            formatDate(selectedTask.nextRunAt)
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.auditedAt')">{{
            selectedTask.auditedAt ? formatDate(selectedTask.auditedAt) : '-'
          }}</a-descriptions-item>
          <a-descriptions-item
            :label="t('fileUploadAudit.detail.rejectedReason')"
          >{{
            selectedTask.rejectedReason || '-'
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.lastError')">{{
            selectedTask.lastError || '-'
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.createdAt')">{{
            formatDate(selectedTask.createdAt)
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.updatedAt')">{{
            formatDate(selectedTask.updatedAt)
          }}</a-descriptions-item>
          <a-descriptions-item :label="t('fileUploadAudit.detail.result')">
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
  import { ref, reactive, onMounted, computed } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import {
    queryFileUploadAuditTasks,
    getFileUploadAuditTask,
    requeueFileUploadAuditTask,
    type FileUploadAuditTaskListEntry,
    type FileUploadAuditTaskQueryParams,
    type FileUploadAuditTaskDetailEntry,
  } from '@/api/file-upload-audit';

  const { t } = useI18n();
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

  const columns = computed(() => [
    {
      title: t('fileUploadAudit.table.status'),
      dataIndex: 'status',
      slotName: 'status',
      width: 110,
    },
    { title: t('fileUploadAudit.table.scene'), dataIndex: 'scene', width: 140 },
    {
      title: t('fileUploadAudit.table.mediaKind'),
      dataIndex: 'mediaKind',
      slotName: 'mediaKind',
      width: 110,
    },
    {
      title: t('fileUploadAudit.table.objectKey'),
      dataIndex: 'objectKey',
      slotName: 'objectKey',
    },
    {
      title: t('fileUploadAudit.table.provider'),
      dataIndex: 'storageProviderId',
      width: 230,
    },
    {
      title: t('fileUploadAudit.table.attempts'),
      dataIndex: 'attempts',
      width: 90,
    },
    {
      title: t('fileUploadAudit.table.lastError'),
      dataIndex: 'lastError',
      slotName: 'lastError',
    },
    {
      title: t('fileUploadAudit.table.createdAt'),
      dataIndex: 'createdAt',
      slotName: 'createdAt',
      width: 180,
    },
    {
      title: t('fileUploadAudit.table.actions'),
      slotName: 'actions',
      width: 160,
      fixed: 'right',
    },
  ]);

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
        return t('fileUploadAudit.filters.status.pending');
      case 1:
        return t('fileUploadAudit.filters.status.approved');
      case 2:
        return t('fileUploadAudit.filters.status.rejected');
      case 3:
        return t('fileUploadAudit.filters.status.retrying');
      case 4:
        return t('fileUploadAudit.filters.status.failed');
      default:
        return String(status);
    }
  };

  const getMediaKindText = (mediaKind: string) => {
    const keyMap: Record<string, string> = {
      image: 'fileUploadAudit.filters.mediaKind.image',
      video: 'fileUploadAudit.filters.mediaKind.video',
      audio: 'fileUploadAudit.filters.mediaKind.audio',
      text: 'fileUploadAudit.filters.mediaKind.text',
      document: 'fileUploadAudit.filters.mediaKind.document',
      unknown: 'fileUploadAudit.filters.mediaKind.unknown',
    };
    return keyMap[mediaKind] ? t(keyMap[mediaKind]) : mediaKind;
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
      Message.error(e?.message || t('fileUploadAudit.messages.fetchError'));
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
      Message.error(e?.message || t('fileUploadAudit.messages.detailError'));
    } finally {
      setLoading(false);
    }
  };

  const handleRequeue = (record: FileUploadAuditTaskListEntry) => {
    Modal.confirm({
      title: t('fileUploadAudit.messages.requeueTitle'),
      content: t('fileUploadAudit.messages.requeueConfirm', {
        objectKey: record.objectKey,
      }),
      async onOk() {
        try {
          const { data } = await requeueFileUploadAuditTask(record.id);
          if (data?.success) {
            Message.success(
              data.message || t('fileUploadAudit.messages.requeueSuccess')
            );
            fetchData();
          } else {
            Message.error(
              data?.message || t('fileUploadAudit.messages.requeueError')
            );
          }
        } catch (e: any) {
          Message.error(e?.message || t('fileUploadAudit.messages.requeueError'));
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
