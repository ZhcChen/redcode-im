<template>
  <div class="container">
    <Breadcrumb
      :items="['menu.userManagement', 'menu.userManagement.feedback']"
    />
    <a-card class="general-card" :title="$t('menu.userManagement.feedback')">
      <a-row>
        <a-col :flex="1">
          <a-form
            :model="formModel"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
            label-align="left"
          >
            <a-row :gutter="16">
              <a-col :span="8">
                <a-form-item field="userId" :label="$t('feedback.userId')">
                  <a-input
                    v-model="formModel.userId"
                    :placeholder="$t('feedback.userId.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8">
                <a-form-item field="keyword" :label="$t('feedback.keyword')">
                  <a-input
                    v-model="formModel.keyword"
                    :placeholder="$t('feedback.keyword.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8" class="search-actions">
                <a-space>
                  <a-button type="primary" @click="search">
                    <template #icon>
                      <icon-search />
                    </template>
                    {{ $t('feedback.search') }}
                  </a-button>
                  <a-button @click="reset">
                    <template #icon>
                      <icon-refresh />
                    </template>
                    {{ $t('feedback.reset') }}
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
          <a-table-column
            :title="$t('feedback.userNickname')"
            data-index="nickname"
            :width="180"
          >
            <template #cell="{ record }">
              {{ record.nickname || record.username || '-' }}
            </template>
          </a-table-column>

          <a-table-column
            :title="$t('feedback.userPhone')"
            data-index="username"
            :width="150"
          >
            <template #cell="{ record }">
              {{ record.username || '-' }}
            </template>
          </a-table-column>

          <a-table-column
            :title="$t('feedback.contact')"
            data-index="contact"
            :width="200"
            :ellipsis="true"
            :tooltip="true"
          >
            <template #cell="{ record }">
              {{ record.contact || $t('feedback.noContact') }}
            </template>
          </a-table-column>

          <a-table-column
            :title="$t('feedback.content')"
            data-index="content"
            :ellipsis="true"
            :tooltip="{ position: 'top' }"
          >
            <template #cell="{ record }">
              {{ record.content }}
            </template>
          </a-table-column>

          <a-table-column
            :title="$t('feedback.createdAt')"
            data-index="createdAt"
            :width="180"
          >
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
  import { useI18n } from 'vue-i18n';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    getFeedbackList,
    type FeedbackItem,
    type FeedbackListParams,
  } from '@/api/feedback';

  const { loading, setLoading } = useLoading();
  const { t } = useI18n();

  const formModel = reactive({
    userId: '',
    keyword: '',
  });

  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
    showPageSize: true,
  });

  const renderData = ref<FeedbackItem[]>([]);

  const fetchData = async (
    page = pagination.current,
    pageSize = pagination.pageSize
  ) => {
    setLoading(true);
    try {
      const params: FeedbackListParams = {
        page,
        pageSize,
        userId: formModel.userId || undefined,
        keyword: formModel.keyword || undefined,
      };

      const { data } = await getFeedbackList(params, {
        suppressGlobalErrorMessage: true,
      });
      renderData.value = data.feedbacks;
      pagination.current = data.page;
      pagination.pageSize = data.pageSize;
      pagination.total = data.total;
    } catch (error: any) {
      renderData.value = [];
      pagination.total = 0;
      console.error('[feedback] fetch failed', error?.response ?? error);
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackKey: 'feedback.messages.fetchError',
          fallbackMessage: t('feedback.messages.fetchError'),
        })
      );
    } finally {
      setLoading(false);
    }
  };

  const search = () => {
    fetchData(1, pagination.pageSize);
  };

  const reset = () => {
    formModel.userId = '';
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
</style>
