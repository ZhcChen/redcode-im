<template>
  <div class="container">
    <Breadcrumb :items="['menu.chatHistory', 'menu.chatHistory.list']" />
    <a-card class="general-card" :title="$t('menu.chatHistory.list')">
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
                <a-form-item field="room_id" :label="$t('chatHistory.roomId')">
                  <a-input
                    v-model="formModel.room_id"
                    :placeholder="$t('chatHistory.roomId.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8">
                <a-form-item field="user_id" :label="$t('chatHistory.userId')">
                  <a-input
                    v-model="formModel.user_id"
                    :placeholder="$t('chatHistory.userId.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8">
                <a-form-item field="keyword" :label="$t('chatHistory.keyword')">
                  <a-input
                    v-model="formModel.keyword"
                    :placeholder="$t('chatHistory.keyword.placeholder')"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
            </a-row>
            <a-row :gutter="16">
              <a-col :span="8">
                <a-form-item
                  field="start_date"
                  :label="$t('chatHistory.startDate')"
                >
                  <a-date-picker
                    v-model="formModel.start_date"
                    style="width: 100%"
                    :placeholder="$t('chatHistory.startDate.placeholder')"
                    format="YYYY-MM-DD"
                    value-format="YYYY-MM-DD"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8">
                <a-form-item
                  field="end_date"
                  :label="$t('chatHistory.endDate')"
                >
                  <a-date-picker
                    v-model="formModel.end_date"
                    style="width: 100%"
                    :placeholder="$t('chatHistory.endDate.placeholder')"
                    format="YYYY-MM-DD"
                    value-format="YYYY-MM-DD"
                    allow-clear
                  />
                </a-form-item>
              </a-col>
              <a-col :span="8">
                <a-space>
                  <a-button type="primary" @click="search">
                    <template #icon>
                      <icon-search />
                    </template>
                    {{ $t('chatHistory.search') }}
                  </a-button>
                  <a-button @click="reset">
                    <template #icon>
                      <icon-refresh />
                    </template>
                    {{ $t('chatHistory.reset') }}
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
            :title="$t('chatHistory.sender')"
            data-index="sender_name"
            :width="150"
          >
            <template #cell="{ record }">
              <a-space>
                <a-avatar
                  v-if="record.sender_avatar"
                  :size="32"
                  :src="record.sender_avatar"
                />
                <a-avatar v-else :size="32">{{
                  record.sender_name.charAt(0)
                }}</a-avatar>
                <span>{{ record.sender_name }}</span>
              </a-space>
            </template>
          </a-table-column>
          <a-table-column
            :title="$t('chatHistory.room')"
            data-index="room_name"
            :width="200"
          >
            <template #cell="{ record }">
              <a-link @click="viewRoomChatHistory(record.room_id)">
                {{ record.room_name || record.room_id }}
              </a-link>
            </template>
          </a-table-column>
          <a-table-column
            :title="$t('chatHistory.content')"
            data-index="content"
            :ellipsis="true"
            :tooltip="true"
          >
            <template #cell="{ record }">
              <div v-if="record.message_type === 'text'">
                {{ record.content }}
              </div>
              <div v-else-if="record.message_type === 'image'">
                <a-image
                  v-if="
                    record.parts &&
                    record.parts.length > 0 &&
                    record.parts[0].thumbnail_key
                  "
                  :src="record.parts[0].thumbnail_key"
                  :width="50"
                  :height="50"
                  :preview="true"
                />
                <span v-else>{{ $t('chatHistory.image') }}</span>
              </div>
              <div v-else-if="record.message_type === 'file'">
                <a-link
                  v-if="
                    record.parts &&
                    record.parts.length > 0 &&
                    record.parts[0].object_key
                  "
                  :href="record.parts[0].object_key"
                  target="_blank"
                >
                  {{ record.parts[0].file_name || $t('chatHistory.file') }}
                </a-link>
                <span v-else>{{ $t('chatHistory.file') }}</span>
              </div>
              <div v-else>
                {{ record.message_type }}
              </div>
            </template>
          </a-table-column>
          <a-table-column
            :title="$t('chatHistory.createdAt')"
            data-index="created_at"
            :width="180"
          >
            <template #cell="{ record }">
              {{ dayjs(record.created_at).format('YYYY-MM-DD HH:mm:ss') }}
            </template>
          </a-table-column>
          <a-table-column
            :title="$t('chatHistory.operations')"
            data-index="operations"
            :width="150"
          >
            <template #cell="{ record }">
              <a-button
                type="text"
                size="small"
                @click="viewUserChatHistory(record.sender_id)"
              >
                {{ $t('chatHistory.viewUserHistory') }}
              </a-button>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { computed, ref, reactive, watch } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { Pagination } from '@/types/global';
  import {
    getChatHistory,
    type ChatMessage,
    type ChatHistoryParams,
  } from '@/api/chat-history';
  import { Message } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import { useRouter } from 'vue-router';

  const { loading, setLoading } = useLoading(true);
  const { t } = useI18n();
  const router = useRouter();

  const generateFormModel = () => {
    return {
      room_id: '',
      user_id: '',
      keyword: '',
      start_date: '',
      end_date: '',
    };
  };
  const formModel = ref(generateFormModel());

  const basePagination: Pagination = {
    current: 1,
    pageSize: 20,
  };
  const pagination = reactive({
    ...basePagination,
    showTotal: true,
    showPageSize: true,
  });

  const renderData = ref<ChatMessage[]>([]);

  const fetchData = async (
    params: ChatHistoryParams = { page: 1, pageSize: 20 }
  ) => {
    setLoading(true);
    try {
      const { data } = await getChatHistory({
        ...params,
        room_id: formModel.value.room_id || undefined,
        user_id: formModel.value.user_id || undefined,
        keyword: formModel.value.keyword || undefined,
        start_date: formModel.value.start_date || undefined,
        end_date: formModel.value.end_date || undefined,
      });
      renderData.value = data.messages;
      pagination.current = data.page;
      pagination.total = data.total;
    } catch (err) {
      Message.error(t('chatHistory.fetchError'));
    } finally {
      setLoading(false);
    }
  };

  const search = () => {
    fetchData({
      page: 1,
      pageSize: pagination.pageSize,
    });
  };

  const onPageChange = (current: number) => {
    pagination.current = current;
    fetchData({
      page: current,
      pageSize: pagination.pageSize,
    });
  };

  const onPageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    fetchData({
      page: 1,
      pageSize,
    });
  };

  const reset = () => {
    formModel.value = generateFormModel();
    fetchData({
      page: 1,
      pageSize: pagination.pageSize,
    });
  };

  const viewRoomChatHistory = (roomId: string) => {
    router.push({
      name: 'RoomChatHistory',
      params: { roomId },
    });
  };

  const viewUserChatHistory = (userId: string) => {
    router.push({
      name: 'UserChatHistory',
      params: { userId },
    });
  };

  fetchData();
</script>

<style scoped lang="less">
  .container {
    padding: 0 20px 20px;
  }

  :deep(.arco-table-th) {
    &:last-child {
      .arco-table-th-item-title {
        margin-left: 16px;
      }
    }
  }
</style>
