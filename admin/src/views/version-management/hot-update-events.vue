<template>
  <div class="hot-update-events-container">
    <Breadcrumb :items="['menu.version', 'menu.version.hotUpdateEvents']" />
    <a-card
      class="general-card"
      :title="t('hotUpdateEvents.title')"
      :bordered="false"
    >
      <a-form
        :model="filters"
        layout="inline"
        :gutter="16"
        @submit.prevent="fetchEvents"
      >
        <a-form-item :label="t('hotUpdateEvents.filter.platform')">
          <a-select v-model="filters.platform" style="width: 140px">
            <a-option value="" :label="t('hotUpdateEvents.filter.all')" />
            <a-option :value="AppPlatform.Android" label="Android" />
            <a-option :value="AppPlatform.IOS" label="iOS" />
          </a-select>
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.channel')">
          <a-input
            v-model="filters.channel"
            :placeholder="t('hotUpdateEvents.filter.channel.placeholder')"
            style="width: 150px"
          />
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.eventType')">
          <a-select v-model="filters.eventType" style="width: 150px">
            <a-option value="" :label="t('hotUpdateEvents.filter.all')" />
            <a-option
              v-for="type in eventTypes"
              :key="type.value"
              :value="type.value"
            >
              {{ type.label }}
            </a-option>
          </a-select>
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.clientType')">
          <a-select v-model="filters.clientType" style="width: 140px">
            <a-option value="" :label="t('hotUpdateEvents.filter.all')" />
            <a-option
              value="desktop"
              :label="t('hotUpdateEvents.filter.client.desktop')"
            />
            <a-option
              value="frontend"
              :label="t('hotUpdateEvents.filter.client.frontend')"
            />
          </a-select>
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.triggerSource')">
          <a-select v-model="filters.triggerSource" style="width: 130px">
            <a-option value="" :label="t('hotUpdateEvents.filter.all')" />
            <a-option
              value="manual"
              :label="t('hotUpdateEvents.filter.trigger.manual')"
            />
            <a-option
              value="auto"
              :label="t('hotUpdateEvents.filter.trigger.auto')"
            />
            <a-option
              value="notification"
              :label="t('hotUpdateEvents.filter.trigger.notification')"
            />
          </a-select>
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.networkType')">
          <a-select v-model="filters.networkType" style="width: 130px">
            <a-option value="" :label="t('hotUpdateEvents.filter.all')" />
            <a-option value="wifi" label="WiFi" />
            <a-option
              value="cellular"
              :label="t('hotUpdateEvents.filter.network.cellular')"
            />
            <a-option
              value="ethernet"
              :label="t('hotUpdateEvents.filter.network.ethernet')"
            />
            <a-option
              value="unknown"
              :label="t('hotUpdateEvents.filter.network.unknown')"
            />
          </a-select>
        </a-form-item>
        <a-form-item :label="t('hotUpdateEvents.filter.timeRange')">
          <a-range-picker
            v-model="filters.range"
            style="width: 260px"
            allow-clear
          />
        </a-form-item>
        <a-form-item>
          <a-button type="primary" :loading="loading" @click="fetchEvents">
            {{ t('hotUpdateEvents.action.query') }}
          </a-button>
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
        <template #client_type="{ record }">
          <a-tag v-if="record.client_type === 'desktop'" color="blue">
            {{ t('hotUpdateEvents.filter.client.desktop') }}
          </a-tag>
          <a-tag v-else-if="record.client_type === 'frontend'" color="green">
            {{ t('hotUpdateEvents.filter.client.frontend') }}
          </a-tag>
          <span v-else>{{ record.client_type ?? '-' }}</span>
        </template>
        <template #event_type="{ record }">
          <a-tag :color="eventColor(record.event_type)">
            {{ eventLabel(record.event_type) }}
          </a-tag>
        </template>
        <template #trigger_source="{ record }">
          <a-tag v-if="record.trigger_source === 'manual'" color="blue">
            {{ t('hotUpdateEvents.filter.trigger.manual') }}
          </a-tag>
          <a-tag v-else-if="record.trigger_source === 'auto'" color="orange">
            {{ t('hotUpdateEvents.filter.trigger.auto') }}
          </a-tag>
          <a-tag
            v-else-if="record.trigger_source === 'notification'"
            color="purple"
          >
            {{ t('hotUpdateEvents.filter.trigger.notification') }}
          </a-tag>
          <span v-else>{{ record.trigger_source ?? '-' }}</span>
        </template>
        <template #os_version="{ record }">
          <a-tooltip :content="record.os_version || '-'">
            <span
              class="text-truncate"
              style="display: inline-block; max-width: 130px"
            >
              {{ record.os_version ?? '-' }}
            </span>
          </a-tooltip>
        </template>
        <template #app_arch="{ record }">
          <a-tag v-if="record.app_arch" size="small">
            {{ record.app_arch }}
          </a-tag>
          <span v-else>-</span>
        </template>
        <template #network_type="{ record }">
          <a-tag
            v-if="record.network_type === 'wifi'"
            color="green"
            size="small"
          >
            WiFi
          </a-tag>
          <a-tag
            v-else-if="record.network_type === 'cellular'"
            color="blue"
            size="small"
          >
            {{ t('hotUpdateEvents.filter.network.cellular') }}
          </a-tag>
          <a-tag
            v-else-if="record.network_type === 'ethernet'"
            color="orange"
            size="small"
          >
            {{ t('hotUpdateEvents.filter.network.ethernet') }}
          </a-tag>
          <span v-else>{{ record.network_type ?? '-' }}</span>
        </template>
        <template #created_at="{ record }">
          {{ formatDate(record.created_at) }}
        </template>
        <template #actions="{ record }">
          <a-button type="text" size="small" @click="showEventDetail(record)">
            {{ t('hotUpdateEvents.action.detail') }}
          </a-button>
        </template>
      </a-table>

      <a-modal
        v-model:visible="detailModalVisible"
        :title="t('hotUpdateEvents.modal.title')"
        width="800px"
        :footer="false"
      >
        <div v-if="selectedEvent" class="event-detail">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.eventId')">
              <a-typography-text copyable>{{
                selectedEvent.id
              }}</a-typography-text>
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.time')">
              {{ formatDate(selectedEvent.created_at) }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.platform')">
              <a-tag>{{
                PlatformLabels[selectedEvent.platform as AppPlatform] ??
                selectedEvent.platform
              }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item
              :label="t('hotUpdateEvents.detail.clientType')"
            >
              <a-tag
                v-if="selectedEvent.client_type === 'desktop'"
                color="blue"
              >
                {{ t('hotUpdateEvents.filter.client.desktop') }}
              </a-tag>
              <a-tag
                v-else-if="selectedEvent.client_type === 'frontend'"
                color="green"
              >
                {{ t('hotUpdateEvents.filter.client.frontend') }}
              </a-tag>
              <span v-else>
                {{
                  selectedEvent.client_type ??
                  t('hotUpdateEvents.filter.network.unknown')
                }}
              </span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.channel')">
              {{ selectedEvent.channel ?? '-' }}
            </a-descriptions-item>
            <a-descriptions-item
              :label="t('hotUpdateEvents.detail.triggerSource')"
            >
              <a-tag
                v-if="selectedEvent.trigger_source === 'manual'"
                color="blue"
              >
                {{ t('hotUpdateEvents.filter.trigger.manual') }}
              </a-tag>
              <a-tag
                v-else-if="selectedEvent.trigger_source === 'auto'"
                color="orange"
              >
                {{ t('hotUpdateEvents.filter.trigger.auto') }}
              </a-tag>
              <a-tag
                v-else-if="selectedEvent.trigger_source === 'notification'"
                color="purple"
              >
                {{ t('hotUpdateEvents.filter.trigger.notification') }}
              </a-tag>
              <span v-else>
                {{
                  selectedEvent.trigger_source ??
                  t('hotUpdateEvents.filter.network.unknown')
                }}
              </span>
            </a-descriptions-item>
            <a-descriptions-item
              :label="t('hotUpdateEvents.detail.versionInfo')"
            >
              {{ selectedEvent.base_version }} →
              {{ selectedEvent.patch_version }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.eventType')">
              <a-tag :color="eventColor(selectedEvent.event_type)">
                {{ eventLabel(selectedEvent.event_type) }}
              </a-tag>
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.osVersion')">
              {{
                selectedEvent.os_version ??
                t('hotUpdateEvents.filter.network.unknown')
              }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.arch')">
              {{ t('hotUpdateEvents.detail.arch.app') }}:
              {{
                selectedEvent.app_arch ??
                t('hotUpdateEvents.filter.network.unknown')
              }}
              <br />
              {{ t('hotUpdateEvents.detail.arch.system') }}:
              {{
                selectedEvent.os_arch ??
                t('hotUpdateEvents.filter.network.unknown')
              }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.network')">
              <a-tag v-if="selectedEvent.network_type === 'wifi'" color="green">
                WiFi
              </a-tag>
              <a-tag
                v-else-if="selectedEvent.network_type === 'cellular'"
                color="blue"
              >
                {{ t('hotUpdateEvents.filter.network.cellular') }}
              </a-tag>
              <a-tag
                v-else-if="selectedEvent.network_type === 'ethernet'"
                color="orange"
              >
                {{ t('hotUpdateEvents.filter.network.ethernet') }}
              </a-tag>
              <span v-else>
                {{
                  selectedEvent.network_type ??
                  t('hotUpdateEvents.filter.network.unknown')
                }}
              </span>
            </a-descriptions-item>
            <a-descriptions-item
              :label="t('hotUpdateEvents.detail.buildNumber')"
            >
              {{ selectedEvent.build_number ?? '-' }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('hotUpdateEvents.detail.clientId')">
              <a-typography-text v-if="selectedEvent.client_id" copyable>
                {{ selectedEvent.client_id }}
              </a-typography-text>
              <span v-else>-</span>
            </a-descriptions-item>
          </a-descriptions>

          <div v-if="selectedEvent.device_info" class="device-info-section">
            <h4>{{ t('hotUpdateEvents.detail.deviceInfo') }}</h4>
            <a-textarea
              :value="formatDeviceInfo(selectedEvent.device_info)"
              readonly
              :auto-size="{ minRows: 3, maxRows: 10 }"
            />
          </div>

          <div v-if="selectedEvent.message" class="message-section">
            <h4>{{ t('hotUpdateEvents.detail.message') }}</h4>
            <a-alert
              :type="
                selectedEvent.event_type.includes('failed') ? 'error' : 'info'
              "
              :message="selectedEvent.message"
              show-icon
            />
          </div>
        </div>
      </a-modal>

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
  import { reactive, ref, onMounted, computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { Message } from '@arco-design/web-vue';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    listHotUpdateEvents,
    type HotUpdateEventInfo,
    type ListHotUpdateEventsParams,
  } from '@/api/hot-update';
  import { AppPlatform, PlatformLabels } from '@/api/app-version';

  const { t } = useI18n();
  const loading = ref(false);
  const events = ref<HotUpdateEventInfo[]>([]);
  const total = ref(0);
  const detailModalVisible = ref(false);
  const selectedEvent = ref<HotUpdateEventInfo | null>(null);

  const filters = reactive({
    platform: '' as string,
    channel: '',
    eventType: '',
    range: [] as (string | Date)[],
    clientType: '',
    triggerSource: '',
    networkType: '',
  });

  const pagination = reactive({
    page: 1,
    pageSize: 20,
  });

  const eventTypes = computed(() => [
    {
      value: 'download_success',
      label: t('hotUpdateEvents.event.downloadSuccess'),
    },
    {
      value: 'download_failed',
      label: t('hotUpdateEvents.event.downloadFailed'),
    },
    {
      value: 'apply_success',
      label: t('hotUpdateEvents.event.applySuccess'),
    },
    {
      value: 'apply_failed',
      label: t('hotUpdateEvents.event.applyFailed'),
    },
    { value: 'rollback', label: t('hotUpdateEvents.event.rollback') },
  ]);

  const columns = computed(() => [
    {
      title: t('hotUpdateEvents.table.time'),
      dataIndex: 'created_at',
      slotName: 'created_at',
      width: 180,
    },
    {
      title: t('hotUpdateEvents.table.platform'),
      dataIndex: 'platform',
      slotName: 'platform',
      width: 100,
    },
    {
      title: t('hotUpdateEvents.table.clientType'),
      dataIndex: 'client_type',
      slotName: 'client_type',
      width: 120,
    },
    {
      title: t('hotUpdateEvents.table.channel'),
      dataIndex: 'channel',
      slotName: 'channel',
      width: 100,
    },
    {
      title: t('hotUpdateEvents.table.baseVersion'),
      dataIndex: 'base_version',
      width: 120,
    },
    {
      title: t('hotUpdateEvents.table.patchVersion'),
      dataIndex: 'patch_version',
      width: 120,
    },
    {
      title: t('hotUpdateEvents.table.event'),
      dataIndex: 'event_type',
      slotName: 'event_type',
      width: 120,
    },
    {
      title: t('hotUpdateEvents.table.triggerSource'),
      dataIndex: 'trigger_source',
      slotName: 'trigger_source',
      width: 100,
    },
    {
      title: t('hotUpdateEvents.table.osVersion'),
      dataIndex: 'os_version',
      slotName: 'os_version',
      width: 140,
    },
    {
      title: t('hotUpdateEvents.table.arch'),
      dataIndex: 'app_arch',
      slotName: 'app_arch',
      width: 100,
    },
    {
      title: t('hotUpdateEvents.table.network'),
      dataIndex: 'network_type',
      slotName: 'network_type',
      width: 100,
    },
    {
      title: t('hotUpdateEvents.table.clientId'),
      dataIndex: 'client_id',
      width: 140,
    },
    {
      title: t('hotUpdateEvents.table.message'),
      dataIndex: 'message',
      ellipsis: true,
      width: 200,
    },
    {
      title: t('hotUpdateEvents.table.operations'),
      dataIndex: 'actions',
      slotName: 'actions',
      width: 80,
      fixed: 'right',
    },
  ]);

  const formatDate = (value: string) =>
    dayjs(value).format('YYYY-MM-DD HH:mm:ss');

  const eventLabel = (value: string) => {
    const map: Record<string, string> = {
      download_success: t('hotUpdateEvents.event.downloadSuccess'),
      download_failed: t('hotUpdateEvents.event.downloadFailed'),
      apply_success: t('hotUpdateEvents.event.applySuccess'),
      apply_failed: t('hotUpdateEvents.event.applyFailed'),
      rollback: t('hotUpdateEvents.event.rollback'),
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
    if (filters.clientType) params.client_type = filters.clientType;
    if (filters.triggerSource) params.trigger_source = filters.triggerSource;
    if (filters.networkType) params.network_type = filters.networkType;
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
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('hotUpdateEvents.fetch.error'),
        })
      );
    } finally {
      loading.value = false;
    }
  };

  const handlePageChange = (page: number) => {
    pagination.page = page;
    fetchEvents();
  };

  const showEventDetail = (event: HotUpdateEventInfo) => {
    selectedEvent.value = event;
    detailModalVisible.value = true;
  };

  const formatDeviceInfo = (deviceInfo: string): string => {
    if (!deviceInfo) return '';

    return deviceInfo
      .split(',')
      .map((pair) => {
        const [key, value] = pair.split(':');
        return `${key}: ${value}`;
      })
      .join('\n');
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

  .text-truncate {
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
  }

  @media (max-width: 1400px) {
    :deep(.arco-table-th),
    :deep(.arco-table-td) {
      padding: 8px 4px;
    }
  }

  :deep(.arco-table-container) {
    overflow-x: auto;
  }

  :deep(.arco-tag) {
    margin: 0;
  }

  .event-detail {
    .device-info-section {
      margin-top: 20px;

      h4 {
        margin-bottom: 8px;
        color: rgb(var(--arcoblue-6));
        font-weight: 500;
      }

      :deep(.arco-textarea) {
        font-size: 12px;
        font-family: Monaco, Menlo, 'Ubuntu Mono', monospace;
        line-height: 1.5;
      }
    }

    .message-section {
      margin-top: 20px;

      h4 {
        margin-bottom: 8px;
        color: rgb(var(--arcoblue-6));
        font-weight: 500;
      }

      :deep(.arco-alert) {
        margin-bottom: 0;
      }
    }
  }

  :deep(.arco-descriptions-item-label) {
    color: rgb(var(--gray-8));
    font-weight: 500;
  }

  :deep(.arco-descriptions-item-content) {
    word-break: break-word;
  }
</style>
