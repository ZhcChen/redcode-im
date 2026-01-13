<template>
  <Dialog
    v-model="isVisible"
    title="操作日志"
    :disable-text-selection="true"
    :show-cancel="false"
    confirm-text="关闭"
    width="600px"
    @confirm="handleClose"
    @cancel="handleClose"
  >
    <div class="logs-dialog-content">
      <div v-if="loading" class="loading-state">加载中...</div>
      <div v-else-if="logs.length === 0" class="empty-state">暂无操作日志</div>
      <div v-else class="logs-list">
        <div
          v-for="log in logs"
          :key="log.id"
          class="log-item"
        >
          <div class="log-time">{{ formatTime(log.createdAt) }}</div>
          <div class="log-content">
            <span class="log-operator">{{ getMemberName(log.operatorId) }}</span>
            <span class="log-action">{{ getOperationText(log) }}</span>
            <span v-if="log.targetUserId" class="log-target">
              {{ getMemberName(log.targetUserId) }}
            </span>
          </div>
        </div>
      </div>

      <!-- 加载更多按钮 -->
      <div v-if="hasMore && !loading" class="load-more">
        <button @click="loadMore">加载更多</button>
      </div>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import { GroupApi, type GroupOperationLog } from '@/api/group'
import type { RoomMember } from '@/types/models'

interface Props {
  visible: boolean
  roomId: string
  members: RoomMember[]
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

const loading = ref(false)
const logs = ref<GroupOperationLog[]>([])
const hasMore = ref(false)
const pageSize = 20

const getMemberName = (userId: string): string => {
  const member = props.members.find(m => m.userId === userId)
  return member?.nickname || member?.username || '未知用户'
}

const formatTime = (date: Date): string => {
  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

const operationTextMap: Record<string, string> = {
  // 管理员相关
  appoint_admin: '任命',
  remove_admin: '撤销了管理员',
  // 成员相关
  add_members: '添加了成员',
  remove_member: '移除了成员',
  // 禁言相关
  enable_global_mute: '开启了全体禁言',
  disable_global_mute: '关闭了全体禁言',
  mute_user: '禁言了',
  unmute_user: '解除了禁言',
  // 群规相关
  create_rule: '创建了群规',
  update_rule: '更新了群规',
  delete_rule: '删除了群规',
  // 入群相关
  create_invitations: '邀请成员入群',
  respond_to_invitation: '响应了群邀请',
  review_join_request: '审核了入群申请',
  // 设置相关
  update_group_settings: '更新了群设置',
}

const getOperationText = (log: GroupOperationLog): string => {
  const baseText = operationTextMap[log.operationType] || log.operationType

  // 特殊处理某些操作的详情
  if (log.operationType === 'appoint_admin' && log.operationData) {
    const role = log.operationData.role as string
    return `任命为${role === 'admin' ? '管理员' : role}`
  }

  if (log.operationType === 'review_join_request' && log.operationData) {
    const status = log.operationData.status as string
    return status === 'approved' ? '通过了入群申请' : '拒绝了入群申请'
  }

  if (log.operationType === 'mute_user' && log.operationData) {
    const hours = log.operationData.duration_hours as number
    if (hours === 0) {
      return '永久禁言了'
    }
    return `禁言${hours}小时`
  }

  return baseText
}

const loadLogs = async (append = false) => {
  if (!props.roomId) return
  loading.value = true
  try {
    const resp = await GroupApi.listOperationLogs({
      roomId: props.roomId,
      limit: pageSize,
      offset: append ? logs.value.length : 0
    })
    if (resp.success && resp.data) {
      if (append) {
        logs.value.push(...resp.data.logs)
      } else {
        logs.value = resp.data.logs
      }
      hasMore.value = resp.data.logs.length >= pageSize
    }
  } catch (error) {
    console.error('加载操作日志失败:', error)
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('close')
}

const loadMore = () => {
  loadLogs(true)
}

watch(() => props.visible, (visible) => {
  if (visible) {
    logs.value = []
    hasMore.value = false
    loadLogs()
  }
})
</script>

<style lang="scss" scoped>
.logs-dialog-content {
  max-height: 450px;
  overflow-y: auto;
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 40px;
  color: #999;
  font-size: 14px;
}

.logs-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.log-item {
  display: flex;
  align-items: flex-start;
  gap: 16px;
  padding: 10px 12px;
  background: #f9f9f9;
  border-radius: 6px;
}

.log-time {
  font-size: 12px;
  color: #999;
  white-space: nowrap;
  flex-shrink: 0;
}

.log-content {
  font-size: 14px;
  color: #333;
  line-height: 1.4;
}

.log-operator {
  color: #1890ff;
  font-weight: 500;
}

.log-action {
  color: #666;
  margin: 0 4px;
}

.log-target {
  color: #1890ff;
  font-weight: 500;
}

.load-more {
  text-align: center;
  margin-top: 16px;

  button {
    padding: 8px 24px;
    background: #f5f5f5;
    border: 1px solid #d9d9d9;
    border-radius: 4px;
    font-size: 14px;
    color: #666;
    cursor: pointer;

    &:hover {
      background: #e8e8e8;
    }
  }
}
</style>
