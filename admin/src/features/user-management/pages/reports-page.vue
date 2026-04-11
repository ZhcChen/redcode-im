<template>
  <div class="container">
    <Breadcrumb
      :items="['menu.userManagement', 'menu.userManagement.reports']"
    />
    <a-card class="general-card" :title="$t('menu.userManagement.reports')">
      <a-row>
        <a-col :flex="1">
          <a-form
            :model="formModel"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            label-align="left"
          >
            <a-row :gutter="16">
              <a-col :span="6">
                <a-form-item
                  field="reporterId"
                  :label="$t('report.reporterId')"
                >
                  <a-input
                    v-model="formModel.reporterId"
                    :placeholder="$t('report.reporterId.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>

              <a-col :span="6">
                <a-form-item
                  field="targetType"
                  :label="$t('report.targetType')"
                >
                  <a-select
                    v-model="formModel.targetType"
                    :placeholder="$t('report.targetType.placeholder')"
                    allow-clear
                  >
                    <a-option value="room">{{
                      $t('report.target.room')
                    }}</a-option>
                    <a-option value="user">{{
                      $t('report.target.user')
                    }}</a-option>
                  </a-select>
                </a-form-item>
              </a-col>

              <a-col :span="6">
                <a-form-item field="targetId" :label="$t('report.targetId')">
                  <a-input
                    v-model="formModel.targetId"
                    :placeholder="$t('report.targetId.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>

              <a-col :span="6">
                <a-form-item field="keyword" :label="$t('report.keyword')">
                  <a-input
                    v-model="formModel.keyword"
                    :placeholder="$t('report.keyword.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
            </a-row>

            <a-row :gutter="16">
              <a-col :span="24" class="search-actions">
                <a-space>
                  <a-button type="primary" @click="search">
                    <template #icon>
                      <icon-search />
                    </template>
                    {{ $t('report.search') }}
                  </a-button>
                  <a-button @click="reset">
                    <template #icon>
                      <icon-refresh />
                    </template>
                    {{ $t('report.reset') }}
                  </a-button>
                </a-space>
              </a-col>
            </a-row>
          </a-form>
        </a-col>
      </a-row>

      <a-divider style="height: 1px" />

      <a-table
        row-key="id"
        :loading="loading"
        :pagination="pagination"
        :data="renderData"
        :bordered="false"
        @page-change="onPageChange"
        @page-size-change="onPageSizeChange"
      >
        <template #columns>
          <a-table-column :title="$t('report.reporter')" :width="220">
            <template #cell="{ record }">
              <div class="reporter">
                <div class="reporter__name">
                  {{
                    record.reporterNickname || record.reporterUsername || '-'
                  }}
                </div>
                <div class="reporter__meta">
                  {{ record.reporterId }}
                </div>
              </div>
            </template>
          </a-table-column>

          <a-table-column :title="$t('report.targetType')" :width="260">
            <template #cell="{ record }">
              <div class="target">
                <a-tag v-if="record.targetType === 'room'" color="green">
                  {{ $t('report.target.room') }}
                </a-tag>
                <a-tag v-else-if="record.targetType === 'user'" color="blue">
                  {{ $t('report.target.user') }}
                </a-tag>
                <a-tag v-else color="gray">{{
                  record.targetType || '-'
                }}</a-tag>

                <span class="target__name">
                  {{ record.targetName || record.targetId || '-' }}
                </span>
              </div>
            </template>
          </a-table-column>

          <a-table-column
            :title="$t('report.content')"
            data-index="content"
            :ellipsis="true"
            :tooltip="{ position: 'top' }"
          >
            <template #cell="{ record }">
              {{ record.content }}
            </template>
          </a-table-column>

          <a-table-column :title="$t('report.attachments')" :width="200">
            <template #cell="{ record }">
              <a-space wrap>
                <a-image
                  v-for="att in record.attachments || []"
                  :key="att.key"
                  :src="att.downloadUrl || ''"
                  :width="48"
                  :height="48"
                  :preview="true"
                />
              </a-space>
            </template>
          </a-table-column>

          <a-table-column :title="$t('report.createdAt')" :width="180">
            <template #cell="{ record }">
              {{ dayjs(record.createdAt).format('YYYY-MM-DD HH:mm:ss') }}
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { onMounted, reactive, ref } from 'vue';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import {
    getReportList,
    type ReportItem,
    type ReportListParams,
  } from '@/services/report';

  const { loading, setLoading } = useLoading();

  const formModel = reactive({
    reporterId: '',
    targetType: '' as '' | 'room' | 'user',
    targetId: '',
    keyword: '',
  });

  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
    showPageSize: true,
  });

  const renderData = ref<ReportItem[]>([]);

  const fetchData = async (
    page = pagination.current,
    pageSize = pagination.pageSize
  ) => {
    setLoading(true);
    try {
      const params: ReportListParams = {
        page,
        pageSize,
        reporterId: formModel.reporterId || undefined,
        targetType: formModel.targetType || undefined,
        targetId: formModel.targetId || undefined,
        keyword: formModel.keyword || undefined,
      };

      const { data } = await getReportList(params);
      renderData.value = data.reports;
      pagination.current = data.page;
      pagination.pageSize = data.pageSize;
      pagination.total = data.total;
    } catch (error: any) {
      renderData.value = [];
      pagination.total = 0;
      console.error('获取举报列表失败', error?.response ?? error);
      Message.error(
        error?.response?.data?.message || error?.message || '获取举报列表失败'
      );
    } finally {
      setLoading(false);
    }
  };

  const search = () => {
    fetchData(1, pagination.pageSize);
  };

  const reset = () => {
    formModel.reporterId = '';
    formModel.targetType = '';
    formModel.targetId = '';
    formModel.keyword = '';
    fetchData(1, pagination.pageSize);
  };

  const onPageChange = (page: number) => {
    fetchData(page, pagination.pageSize);
  };

  const onPageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    fetchData(1, pageSize);
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style scoped>
  .container {
    padding: 16px;
  }

  .general-card {
    margin-top: 16px;
  }

  .search-actions {
    display: flex;
    align-items: flex-end;
  }

  .reporter {
    display: flex;
    flex-direction: column;
    gap: 2px;
    line-height: 1.2;
  }

  .reporter__name {
    color: var(--color-text-1);
  }

  .reporter__meta {
    color: var(--color-text-3);
    font-size: 12px;
  }

  .target {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .target__name {
    color: var(--color-text-2);
  }
</style>
