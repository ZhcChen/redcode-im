<template>
  <div class="container">
    <Breadcrumb :items="['menu.chatHistory', 'menu.chatHistory.user']" />
    <a-card
      class="general-card"
      :title="`${$t('chatHistory.userHistory')}: ${userName || userId}`"
    >
      <a-tabs v-model:active-key="activeTab" type="card">
        <a-tab-pane key="rooms" :title="$t('chatHistory.userRooms')">
          <a-table
            row-key="id"
            :loading="roomsLoading"
            :data="roomsData"
            :bordered="false"
            :pagination="false"
          >
            <template #columns>
              <a-table-column
                :title="$t('chatHistory.roomName')"
                data-index="name"
                :width="200"
              >
                <template #cell="{ record }">
                  <a-space>
                    <a-avatar
                      v-if="record.avatar_url"
                      :size="32"
                      :src="record.avatar_url"
                    />
                    <a-avatar v-else :size="32">{{
                      record.name.charAt(0)
                    }}</a-avatar>
                    <span>{{ record.name }}</span>
                  </a-space>
                </template>
              </a-table-column>
              <a-table-column
                :title="$t('chatHistory.roomType')"
                data-index="is_group"
                :width="100"
              >
                <template #cell="{ record }">
                  <a-tag v-if="record.is_group" color="blue">{{
                    $t('chatHistory.group')
                  }}</a-tag>
                  <a-tag v-else color="green">{{
                    $t('chatHistory.private')
                  }}</a-tag>
                </template>
              </a-table-column>
              <a-table-column
                :title="$t('chatHistory.memberCount')"
                data-index="member_count"
                :width="100"
              />
              <a-table-column
                :title="$t('chatHistory.lastMessage')"
                data-index="last_message"
                :ellipsis="true"
                :tooltip="true"
              >
                <template #cell="{ record }">
                  <div v-if="record.last_message">
                    <div v-if="record.last_message.message_type === 'text'">
                      {{ record.last_message.content }}
                    </div>
                    <div v-else> [{{ record.last_message.message_type }}] </div>
                    <div class="last-message-time">
                      {{
                        dayjs(record.last_message.created_at).format(
                          'YYYY-MM-DD HH:mm:ss'
                        )
                      }}
                    </div>
                  </div>
                  <span v-else>{{ $t('chatHistory.noMessages') }}</span>
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
                    @click="viewRoomChatHistory(record.id)"
                  >
                    {{ $t('chatHistory.viewRoomHistory') }}
                  </a-button>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-tab-pane>
        <a-tab-pane key="messages" :title="$t('chatHistory.userMessages')">
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
                    <a-form-item
                      field="room_id"
                      :label="$t('chatHistory.roomId')"
                    >
                      <a-input
                        v-model="formModel.room_id"
                        :placeholder="$t('chatHistory.roomId.placeholder')"
                        allow-clear
                      />
                    </a-form-item>
                  </a-col>
                  <a-col :span="8">
                    <a-form-item
                      field="keyword"
                      :label="$t('chatHistory.keyword')"
                    >
                      <a-input
                        v-model="formModel.keyword"
                        :placeholder="$t('chatHistory.keyword.placeholder')"
                        allow-clear
                      />
                    </a-form-item>
                  </a-col>
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
                </a-row>
                <a-row :gutter="16">
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
            :loading="messagesLoading"
            :pagination="pagination"
            :data="messagesData"
            :bordered="false"
            @page-change="onPageChange"
            @page-size-change="onPageSizeChange"
          >
            <template #columns>
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
                    <a-space direction="vertical">
                      <a-image
                        v-if="record.parts && record.parts.length > 0"
                        :src="
                          record.parts[0].thumbnail_key ||
                          record.parts[0].object_key
                        "
                        :preview-src="record.parts[0].object_key"
                        :width="80"
                        :height="80"
                        :preview="true"
                        style="object-fit: cover; border-radius: 4px"
                      />
                      <a-link
                        v-if="record.parts && record.parts.length > 0"
                        size="small"
                        :href="record.parts[0].object_key"
                        target="_blank"
                        download
                      >
                        <template #icon><icon-download /></template>
                        {{ $t('chatHistory.download') }}
                      </a-link>
                    </a-space>
                  </div>
                  <div v-else-if="record.message_type === 'video'">
                    <a-space direction="vertical">
                      <div
                        class="video-preview-trigger"
                        @click="playVideo(record.parts[0].object_key)"
                      >
                        <icon-play-circle-fill :size="32" />
                        <span>{{ $t('chatHistory.previewVideo') }}</span>
                      </div>
                      <a-link
                        v-if="record.parts && record.parts.length > 0"
                        size="small"
                        :href="record.parts[0].object_key"
                        target="_blank"
                        download
                      >
                        <template #icon><icon-download /></template>
                        {{ $t('chatHistory.download') }}
                      </a-link>
                    </a-space>
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
                      <template #icon><icon-file /></template>
                      {{ record.parts[0].file_name || $t('chatHistory.file') }}
                    </a-link>
                    <span v-else>{{ $t('chatHistory.file') }}</span>
                  </div>
                  <div v-else>
                    <a-tag color="gray">{{ record.message_type }}</a-tag>
                    <div v-if="record.content" style="margin-top: 4px">{{
                      record.content
                    }}</div>
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
            </template>
          </a-table>
        </a-tab-pane>
      </a-tabs>
    </a-card>

    <!-- 视频预览弹窗 -->
    <a-modal
      v-model:visible="videoVisible"
      :footer="false"
      unmount-on-close
      title="视频预览"
      width="auto"
    >
      <video
        :src="currentVideoUrl"
        controls
        autoplay
        style="max-width: 100%; max-height: 70vh"
      ></video>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { computed, ref, reactive, watch, onMounted } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { Pagination } from '@/types/global';
  import {
    getUserRooms,
    getChatHistory,
    type UserRoom,
    type ChatMessage,
  } from '@/api/chat-history';
  import { Message } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import { useRouter, useRoute } from 'vue-router';

  const { loading: roomsLoading, setLoading: setRoomsLoading } =
    useLoading(true);
  const { loading: messagesLoading, setLoading: setMessagesLoading } =
    useLoading(false);
  const { t } = useI18n();
  const router = useRouter();
  const route = useRoute();

  const videoVisible = ref(false);
  const currentVideoUrl = ref('');

  const playVideo = (url: string) => {
    currentVideoUrl.value = url;
    videoVisible.value = true;
  };

  const userId = computed(() => route.params.userId as string);
  const userName = ref('');
  const activeTab = ref('rooms');

  const roomsData = ref<UserRoom[]>([]);
  const messagesData = ref<ChatMessage[]>([]);

  const generateFormModel = () => {
    return {
      room_id: '',
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

  const fetchUserRooms = async () => {
    setRoomsLoading(true);
    try {
      const { data } = await getUserRooms(userId.value);
      roomsData.value = data.rooms;
    } catch (err) {
      Message.error(t('chatHistory.fetchRoomsError'));
    } finally {
      setRoomsLoading(false);
    }
  };

  const fetchUserMessages = async (params: any = { page: 1, pageSize: 20 }) => {
    setMessagesLoading(true);
    try {
      const { data } = await getChatHistory({
        ...params,
        user_id: userId.value,
        room_id: formModel.value.room_id || undefined,
        keyword: formModel.value.keyword || undefined,
        start_date: formModel.value.start_date || undefined,
        end_date: formModel.value.end_date || undefined,
      });
      messagesData.value = data.messages;
      pagination.current = data.page;
      pagination.total = data.total;
    } catch (err) {
      Message.error(t('chatHistory.fetchError'));
    } finally {
      setMessagesLoading(false);
    }
  };

  const search = () => {
    fetchUserMessages({
      page: 1,
      pageSize: pagination.pageSize,
    });
  };

  const onPageChange = (current: number) => {
    pagination.current = current;
    fetchUserMessages({
      page: current,
      pageSize: pagination.pageSize,
    });
  };

  const onPageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    fetchUserMessages({
      page: 1,
      pageSize,
    });
  };

  const reset = () => {
    formModel.value = generateFormModel();
    fetchUserMessages({
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

  // 监听标签页切换
  watch(activeTab, (newTab) => {
    if (newTab === 'rooms') {
      fetchUserRooms();
    } else if (newTab === 'messages') {
      fetchUserMessages();
    }
  });

  onMounted(() => {
    fetchUserRooms();
  });
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

  .last-message-time {
    margin-top: 4px;
    color: var(--color-text-3);
    font-size: 12px;
  }

  .video-preview-trigger {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 80px;
    height: 80px;
    color: var(--color-text-2);
    background-color: var(--color-fill-2);
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.3s;

    &:hover {
      color: var(--color-primary-light-4);
      background-color: var(--color-fill-3);
    }

    span {
      margin-top: 4px;
      font-size: 12px;
    }
  }
</style>
