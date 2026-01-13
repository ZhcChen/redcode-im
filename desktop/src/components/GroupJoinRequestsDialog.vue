<template>
  <Dialog
    v-model="isVisible"
    title="入群审核"
    :disable-text-selection="true"
    :show-cancel="false"
    confirm-text="关闭"
    width="520px"
    @confirm="handleClose"
    @cancel="handleClose"
  >
    <div class="join-requests-content">
      <div v-if="loading" class="loading-state">加载中...</div>
      <div v-else-if="requests.length === 0" class="empty-state">暂无入群申请</div>
      <div v-else class="request-list">
        <div
          v-for="request in requests"
          :key="request.id"
          class="request-item"
        >
          <Avatar
            :src="getUserAvatar(request.applicantId)"
            :text="getUserName(request.applicantId)"
            :color-seed="request.applicantId"
            :size="44"
          />
          <div class="request-info">
            <div class="request-user">{{ getUserName(request.applicantId) }}</div>
            <div class="request-message" v-if="request.message">
              申请理由：{{ request.message }}
            </div>
            <div class="request-time">
              {{ formatTime(request.createdAt) }}
            </div>
          </div>
          <div class="request-actions" v-if="request.status === 'pending'">
            <button class="btn-approve" @click="handleApprove(request)">通过</button>
            <button class="btn-reject" @click="handleReject(request)">拒绝</button>
          </div>
          <div v-else class="request-status" :class="request.status">
            {{ request.status === 'approved' ? '已通过' : '已拒绝' }}
          </div>
        </div>
      </div>
    </div>

    <!-- 确认对话框 -->
    <ConfirmDialog
      v-model:visible="showConfirm"
      :title="confirmTitle"
      :message="confirmMessage"
      :confirm-text="confirmAction"
      :danger="isRejectAction"
      @confirm="executeAction"
    />
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import Avatar from './Avatar.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import { GroupApi, type JoinRequest } from '@/api/group'
import { useToast } from '@/hooks/useToast'

interface UserInfo {
  id: string
  name: string
  avatar?: string
}

interface Props {
  visible: boolean
  roomId: string
  userMap?: Map<string, UserInfo>
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
  (e: 'updated'): void
}

const props = withDefaults(defineProps<Props>(), {
  userMap: () => new Map()
})
const emit = defineEmits<Emits>()
const { showToast } = useToast()

const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

const loading = ref(false)
const requests = ref<JoinRequest[]>([])
const showConfirm = ref(false)
const pendingRequest = ref<JoinRequest | null>(null)
const isRejectAction = ref(false)

const confirmTitle = computed(() => isRejectAction.value ? '拒绝入群' : '通过入群')
const confirmMessage = computed(() => {
  const name = pendingRequest.value ? getUserName(pendingRequest.value.applicantId) : ''
  return isRejectAction.value
    ? `确定要拒绝 ${name} 的入群申请吗？`
    : `确定要通过 ${name} 的入群申请吗？`
})
const confirmAction = computed(() => isRejectAction.value ? '拒绝' : '通过')

const getUserName = (userId: string): string => {
  return props.userMap?.get(userId)?.name || '未知用户'
}

const getUserAvatar = (userId: string): string => {
  return props.userMap?.get(userId)?.avatar || ''
}

const formatTime = (date: Date): string => {
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)

  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`
  if (days < 7) return `${days}天前`

  return date.toLocaleDateString()
}

const loadRequests = async () => {
  if (!props.roomId) return
  loading.value = true
  try {
    const resp = await GroupApi.listJoinRequests({ roomId: props.roomId })
    if (resp.success && resp.data) {
      // 按时间倒序，pending 的排在前面
      requests.value = resp.data.sort((a, b) => {
        if (a.status === 'pending' && b.status !== 'pending') return -1
        if (a.status !== 'pending' && b.status === 'pending') return 1
        return b.createdAt.getTime() - a.createdAt.getTime()
      })
    }
  } catch (error) {
    console.error('加载入群申请失败:', error)
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('close')
}

const handleApprove = (request: JoinRequest) => {
  pendingRequest.value = request
  isRejectAction.value = false
  showConfirm.value = true
}

const handleReject = (request: JoinRequest) => {
  pendingRequest.value = request
  isRejectAction.value = true
  showConfirm.value = true
}

const executeAction = async () => {
  if (!pendingRequest.value) return

  try {
    const resp = await GroupApi.reviewJoinRequest({
      roomId: props.roomId,
      requestId: pendingRequest.value.id,
      status: isRejectAction.value ? 'rejected' : 'approved'
    })
    if (resp.success) {
      showToast(isRejectAction.value ? '已拒绝入群申请' : '已通过入群申请')
      await loadRequests()
      emit('updated')
    } else {
      showToast(resp.message || '操作失败')
    }
  } catch (error) {
    console.error('审核入群申请失败:', error)
    showToast('操作失败')
  }

  pendingRequest.value = null
  showConfirm.value = false
}

watch(() => props.visible, (visible) => {
  if (visible) {
    loadRequests()
  }
})
</script>

<style lang="scss" scoped>
.join-requests-content {
  max-height: 400px;
  overflow-y: auto;
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 40px;
  color: #999;
  font-size: 14px;
}

.request-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.request-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  background: #f9f9f9;
  border-radius: 8px;
}

.request-info {
  flex: 1;
  min-width: 0;
}

.request-user {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.request-message {
  font-size: 13px;
  color: #666;
  margin-top: 4px;
  word-break: break-word;
}

.request-time {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.request-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;

  button {
    padding: 6px 12px;
    border-radius: 4px;
    font-size: 13px;
    cursor: pointer;
    border: none;
    transition: opacity 0.2s;

    &:hover {
      opacity: 0.8;
    }
  }

  .btn-approve {
    background: #52c41a;
    color: white;
  }

  .btn-reject {
    background: #f5f5f5;
    color: #666;
  }
}

.request-status {
  font-size: 13px;
  padding: 4px 8px;
  border-radius: 4px;
  flex-shrink: 0;

  &.approved {
    background: #e6f7ff;
    color: #1890ff;
  }

  &.rejected {
    background: #fff1f0;
    color: #ff4d4f;
  }
}
</style>
