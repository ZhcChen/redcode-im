<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import type { GroupOperationLog } from '@/types/room';

const pageSize = 20;
const route = useRoute();
const router = useRouter();
const roomId = computed(() => String(route.params.roomId ?? ''));
const logs = ref<GroupOperationLog[]>([]);
const loading = ref(false);
const hasMore = ref(true);
const error = ref('');

const operationLabels: Record<string, string> = {
  update_group_settings: '更新了群设置',
  create_rule: '新增了群规',
  update_rule: '修改了群规',
  delete_rule: '删除了群规',
  review_join_request: '处理了入群申请',
  appoint_admin: '任命了管理员',
  remove_admin: '撤销了管理员',
  enable_global_mute: '开启了全体禁言',
  disable_global_mute: '关闭了全体禁言',
  mute_user: '禁言了群成员',
  unmute_user: '解除了成员禁言',
};

const load = async (reset = false) => {
  if (loading.value) return;
  loading.value = true;
  error.value = '';
  try {
    const currentOffset = reset ? 0 : logs.value.length;
    const next = appEnv.useMockData ? createMockLogs().slice(currentOffset, currentOffset + pageSize) : await roomService.listOperationLogs(roomId.value, pageSize, currentOffset);
    logs.value = reset ? next : [...logs.value, ...next];
    hasMore.value = next.length === pageSize;
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载操作日志失败';
  } finally {
    loading.value = false;
  }
};

const describe = (log: GroupOperationLog) => operationLabels[log.operationType] ?? '执行了群管理操作';
const formatTime = (value: string) => value ? new Intl.DateTimeFormat('zh-CN', {
  month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false,
}).format(new Date(value)) : '';
const shortId = (value: string) => value ? `${value.slice(0, 8)}...${value.slice(-4)}` : '未知成员';

onMounted(() => void load(true));

const createMockLogs = (): GroupOperationLog[] => [{
  id: 'mock-log', roomId: roomId.value, operatorId: 'mock-owner-0001', targetUserId: null,
  operationType: 'update_group_settings', operationData: null, createdAt: new Date().toISOString(),
}];
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button>
      <div><h1>操作日志</h1><p>群管理记录</p></div>
      <button class="contact-page__action rc-focus-ring" type="button" :disabled="loading" @click="load(true)">刷新</button>
    </header>
    <section class="contact-page__content">
      <p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p>
      <p v-if="loading && logs.length === 0" class="contact-page__empty">正在加载操作日志...</p>
      <p v-else-if="logs.length === 0" class="contact-page__empty">暂无操作日志</p>
      <ol v-else class="operation-timeline">
        <li v-for="log in logs" :key="log.id" class="operation-log" :data-operation-type="log.operationType">
          <span class="operation-log__marker" aria-hidden="true" />
          <div><h2>{{ describe(log) }}</h2><p>操作人 {{ shortId(log.operatorId) }}<template v-if="log.targetUserId"> · 对象 {{ shortId(log.targetUserId) }}</template></p><time :datetime="log.createdAt">{{ formatTime(log.createdAt) }}</time></div>
        </li>
      </ol>
      <button v-if="hasMore && logs.length > 0" class="load-more rc-focus-ring" type="button" :disabled="loading" @click="load()">{{ loading ? '加载中...' : '加载更多' }}</button>
      <p v-else-if="logs.length > 0" class="operation-end">已显示全部记录</p>
    </section>
  </main>
</template>

<style scoped>
.operation-timeline { display: grid; gap: 0; margin: 0; padding: 0; list-style: none; }
.operation-log { position: relative; display: grid; grid-template-columns: 18px minmax(0, 1fr); gap: 10px; min-height: 82px; padding: 2px 0 18px; }
.operation-log:not(:last-child)::before { position: absolute; top: 13px; bottom: -1px; left: 5px; width: 1px; background: var(--rc-divider); content: ''; }
.operation-log__marker { position: relative; z-index: 1; width: 11px; height: 11px; margin-top: 5px; border: 3px solid var(--rc-primary-soft); border-radius: 50%; background: var(--rc-primary); }
.operation-log h2, .operation-log p { margin: 0; }
.operation-log h2 { color: var(--rc-text-primary); font-size: 15px; }
.operation-log p, .operation-log time { display: block; margin-top: 6px; color: var(--rc-text-tertiary); font-size: 12px; line-height: 1.4; }
.load-more { width: 100%; height: 42px; border-radius: 8px; background: var(--rc-surface); color: var(--rc-primary-strong); }
.operation-end { margin: 0; color: var(--rc-text-tertiary); text-align: center; font-size: 12px; }
</style>
