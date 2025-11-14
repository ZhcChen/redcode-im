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
        <template #event_type="{ record }">
          <a-tag :color="eventColor(record.event_type)">{{
            eventLabel(record.event_type)
          }}</a-tag>
        </template>
        <template #created_at="{ record }">
          {{ formatDate(record.created_at) }}
        </template>
      </a-table>

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
  import { Message } from '@arco-design/web-vue';
  import {
    listHotUpdateEvents,
    type HotUpdateEventInfo,
    type ListHotUpdateEventsParams,
  } from '@/api/hot-update';
  import { AppPlatform, PlatformLabels } from '@/api/app-version';

  const loading = ref(false);
  const events = ref<HotUpdateEventInfo[]>([]);
  const total = ref(0);

  const filters = reactive({
    platform: '' as string,
    channel: '',
    eventType: '',
    range: [] as (string | Date)[],
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

  const columns = [
    {
      title: '时间',
      dataIndex: 'created_at',
      slotName: 'created_at',
      width: 180,
    },
    { title: '平台', dataIndex: 'platform', slotName: 'platform', width: 120 },
    { title: '渠道', dataIndex: 'channel', slotName: 'channel', width: 120 },
    { title: '基线版本', dataIndex: 'base_version', width: 140 },
    { title: '补丁版本', dataIndex: 'patch_version', width: 140 },
    {
      title: '事件',
      dataIndex: 'event_type',
      slotName: 'event_type',
      width: 140,
    },
    { title: '客户端', dataIndex: 'client_id', width: 140 },
    { title: '备注', dataIndex: 'message', ellipsis: true },
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
</style>
