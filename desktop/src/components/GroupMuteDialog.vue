<template>
  <Dialog
    v-model="isVisible"
    title="禁言管理"
    :disable-text-selection="true"
    :show-cancel="false"
    confirm-text="关闭"
    width="520px"
    @confirm="handleClose"
    @cancel="handleClose"
  >
    <div class="mute-dialog-content">
      <!-- 禁言成员按钮 -->
      <div class="action-bar">
        <button class="btn-mute" @click="handleMuteUser">+ 禁言成员</button>
      </div>

      <!-- 当前被禁言的成员列表 -->
      <div class="section">
        <div class="section-title">被禁言的成员</div>
        <div v-if="loading" class="loading-state">加载中...</div>
        <div v-else-if="mutes.length === 0" class="empty-state">暂无被禁言的成员</div>
        <div v-else class="mute-list">
          <div
            v-for="mute in mutes"
            :key="mute.id"
            class="mute-item"
          >
            <Avatar
              :src="getMemberAvatar(mute.userId)"
              :text="getMemberName(mute.userId)"
              :color-seed="mute.userId"
              :size="40"
            />
            <div class="mute-info">
              <div class="mute-name">{{ getMemberName(mute.userId) }}</div>
              <div class="mute-details">
                <span v-if="mute.reason">原因：{{ mute.reason }}</span>
                <span v-if="mute.muteUntil">
                  解禁时间：{{ formatTime(mute.muteUntil) }}
                </span>
                <span v-else>永久禁言</span>
              </div>
            </div>
            <div class="mute-actions">
              <span class="action-btn" @click="handleUnmute(mute)">解除禁言</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 选择成员对话框 -->
    <SelectableListDialog
      v-model:visible="showSelectDialog"
      title="选择要禁言的成员"
      :items="availableMembers"
      item-key="userId"
      :get-label="(m: any) => m.nickname || m.username"
      :get-avatar-src="(m: any) => m.avatarUrl"
      :get-avatar-text="(m: any) => m.nickname || m.username"
      confirm-text="下一步"
      search-placeholder="搜索成员..."
      empty-text="暂无可禁言的成员"
      :filter-fn="filterMember"
      @confirm="handleSelectMember"
    />

    <!-- 禁言时长设置对话框 -->
    <Dialog
      v-model="showDurationDialog"
      title="设置禁言时长"
      confirm-text="确认禁言"
      width="400px"
      @confirm="confirmMute"
      @cancel="showDurationDialog = false"
    >
      <div class="duration-form">
        <div class="form-item">
          <label>禁言时长</label>
          <select v-model="muteDuration">
            <option :value="1">1小时</option>
            <option :value="6">6小时</option>
            <option :value="12">12小时</option>
            <option :value="24">1天</option>
            <option :value="72">3天</option>
            <option :value="168">7天</option>
            <option :value="0">永久</option>
          </select>
        </div>
        <div class="form-item">
          <label>禁言原因（可选）</label>
          <input
            v-model="muteReason"
            type="text"
            placeholder="请输入禁言原因"
            maxlength="100"
          />
        </div>
      </div>
    </Dialog>

    <!-- 确认解禁对话框 -->
    <ConfirmDialog
      v-model:visible="showUnmuteConfirm"
      title="解除禁言"
      :message="`确定要解除 ${pendingUnmute ? getMemberName(pendingUnmute.userId) : ''} 的禁言吗？`"
      confirm-text="解除"
      @confirm="confirmUnmute"
    />
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import Avatar from './Avatar.vue'
import SelectableListDialog from './SelectableListDialog.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import { GroupApi, type GroupMute } from '@/api/group'
import type { RoomMember } from '@/types/models'
import { useToast } from '@/hooks/useToast'

interface Props {
  visible: boolean
  roomId: string
  members: RoomMember[]
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
  (e: 'updated'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()
const { showToast } = useToast()

const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

const loading = ref(false)
const mutes = ref<GroupMute[]>([])
const showSelectDialog = ref(false)
const showDurationDialog = ref(false)
const showUnmuteConfirm = ref(false)
const selectedMemberIds = ref<string[]>([])
const muteDuration = ref(24) // 默认1天
const muteReason = ref('')
const pendingUnmute = ref<GroupMute | null>(null)

// 可禁言的成员（排除已禁言、群主、管理员）
const availableMembers = computed(() => {
  const mutedIds = new Set(mutes.value.map(m => m.userId))
  return props.members.filter(m =>
    m.role === 'member' && !mutedIds.has(m.userId)
  )
})

const getMemberName = (userId: string): string => {
  const member = props.members.find(m => m.userId === userId)
  return member?.nickname || member?.username || '未知用户'
}

const getMemberAvatar = (userId: string): string => {
  const member = props.members.find(m => m.userId === userId)
  return member?.avatarUrl || ''
}

const filterMember = (member: RoomMember, keyword: string): boolean => {
  const lowerKeyword = keyword.toLowerCase()
  return (
    (member.nickname?.toLowerCase().includes(lowerKeyword) ?? false) ||
    member.username.toLowerCase().includes(lowerKeyword)
  )
}

const formatTime = (date: Date): string => {
  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const loadMutes = async () => {
  if (!props.roomId) return
  loading.value = true
  try {
    const resp = await GroupApi.listMutedUsers({ roomId: props.roomId })
    if (resp.success && resp.data) {
      mutes.value = resp.data.filter(m => m.isActive)
    }
  } catch (error) {
    console.error('加载禁言列表失败:', error)
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('close')
}

const handleMuteUser = () => {
  showSelectDialog.value = true
}

const handleSelectMember = (ids: string[]) => {
  if (ids.length === 0) return
  selectedMemberIds.value = ids
  showSelectDialog.value = false
  muteDuration.value = 24
  muteReason.value = ''
  showDurationDialog.value = true
}

const confirmMute = async () => {
  if (selectedMemberIds.value.length === 0) return

  let successCount = 0
  for (const userId of selectedMemberIds.value) {
    try {
      const resp = await GroupApi.muteUser({
        roomId: props.roomId,
        userId,
        durationHours: muteDuration.value,
        reason: muteReason.value || undefined
      })
      if (resp.success) {
        successCount++
      }
    } catch (error) {
      console.error('禁言失败:', error)
    }
  }

  if (successCount > 0) {
    showToast(`成功禁言 ${successCount} 名成员`)
    await loadMutes()
    emit('updated')
  }

  showDurationDialog.value = false
  selectedMemberIds.value = []
}

const handleUnmute = (mute: GroupMute) => {
  pendingUnmute.value = mute
  showUnmuteConfirm.value = true
}

const confirmUnmute = async () => {
  if (!pendingUnmute.value) return

  try {
    const resp = await GroupApi.unmuteUser({
      roomId: props.roomId,
      userId: pendingUnmute.value.userId
    })
    if (resp.success) {
      showToast('已解除禁言')
      await loadMutes()
      emit('updated')
    } else {
      showToast(resp.message || '解除禁言失败')
    }
  } catch (error) {
    console.error('解除禁言失败:', error)
    showToast('解除禁言失败')
  }

  pendingUnmute.value = null
  showUnmuteConfirm.value = false
}

watch(() => props.visible, (visible) => {
  if (visible) {
    loadMutes()
  }
})
</script>

<style lang="scss" scoped>
.mute-dialog-content {
  padding: 0 4px;
}

.action-bar {
  margin-bottom: 16px;

  .btn-mute {
    padding: 8px 16px;
    background: #1890ff;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;

    &:hover {
      opacity: 0.9;
    }
  }
}

.section {
  margin-bottom: 16px;
}

.section-title {
  font-size: 14px;
  font-weight: 500;
  color: #333;
  margin-bottom: 12px;
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 24px;
  color: #999;
  font-size: 14px;
}

.mute-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 300px;
  overflow-y: auto;
}

.mute-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #f5f5f5;
  border-radius: 8px;
}

.mute-info {
  flex: 1;
  min-width: 0;
}

.mute-name {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.mute-details {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
  display: flex;
  gap: 8px;
}

.mute-actions {
  flex-shrink: 0;
}

.action-btn {
  font-size: 13px;
  color: #1890ff;
  cursor: pointer;

  &:hover {
    opacity: 0.8;
  }
}

.duration-form {
  padding: 8px 0;
}

.form-item {
  margin-bottom: 16px;

  &:last-child {
    margin-bottom: 0;
  }

  label {
    display: block;
    font-size: 14px;
    color: #333;
    margin-bottom: 8px;
  }

  select,
  input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d9d9d9;
    border-radius: 4px;
    font-size: 14px;
    outline: none;

    &:focus {
      border-color: #1890ff;
    }
  }
}
</style>
