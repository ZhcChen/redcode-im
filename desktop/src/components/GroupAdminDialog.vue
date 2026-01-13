<template>
  <Dialog
    v-model="isVisible"
    title="管理员设置"
    :disable-text-selection="true"
    :show-cancel="false"
    confirm-text="关闭"
    width="480px"
    @confirm="handleClose"
    @cancel="handleClose"
  >
    <div class="admin-dialog-content">
      <!-- 当前管理员列表 -->
      <div class="section">
        <div class="section-header">
          <span class="section-title">当前管理员</span>
          <span class="section-action" @click="handleAddAdmin">+ 添加管理员</span>
        </div>
        <div v-if="loading" class="loading-state">加载中...</div>
        <div v-else-if="admins.length === 0" class="empty-state">暂无管理员</div>
        <div v-else class="admin-list">
          <div
            v-for="admin in admins"
            :key="admin.id"
            class="admin-item"
          >
            <Avatar
              :src="getMemberAvatar(admin.adminId)"
              :text="getMemberName(admin.adminId)"
              :color-seed="admin.adminId"
              :size="40"
            />
            <div class="admin-info">
              <div class="admin-name">{{ getMemberName(admin.adminId) }}</div>
              <div class="admin-role">{{ admin.role === 'admin' ? '管理员' : admin.role }}</div>
            </div>
            <div class="admin-actions">
              <span class="action-btn danger" @click="handleRemoveAdmin(admin)">撤销</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 添加管理员对话框 -->
    <SelectableListDialog
      v-model:visible="showAddDialog"
      title="添加管理员"
      :items="availableMembers"
      item-key="userId"
      :get-label="(m: any) => m.nickname || m.username"
      :get-avatar-src="(m: any) => m.avatarUrl"
      :get-avatar-text="(m: any) => m.nickname || m.username"
      :get-confirm-text="(count: number) => count > 0 ? `确定添加 (${count})` : '请选择成员'"
      search-placeholder="搜索成员..."
      empty-text="暂无可添加的成员"
      :filter-fn="filterMember"
      @confirm="handleConfirmAddAdmin"
    />

    <!-- 确认撤销对话框 -->
    <ConfirmDialog
      v-model:visible="showRemoveConfirm"
      title="撤销管理员"
      :message="`确定要撤销 ${pendingRemoveAdmin?.adminId ? getMemberName(pendingRemoveAdmin.adminId) : ''} 的管理员权限吗？`"
      confirm-text="撤销"
      :danger="true"
      @confirm="confirmRemoveAdmin"
    />
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import Avatar from './Avatar.vue'
import SelectableListDialog from './SelectableListDialog.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import { GroupApi, type GroupAdmin } from '@/api/group'
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
const admins = ref<GroupAdmin[]>([])
const showAddDialog = ref(false)
const showRemoveConfirm = ref(false)
const pendingRemoveAdmin = ref<GroupAdmin | null>(null)

// 可添加为管理员的成员（排除已是管理员和群主）
const availableMembers = computed(() => {
  const adminIds = new Set(admins.value.map(a => a.adminId))
  return props.members.filter(m =>
    m.role !== 'owner' && !adminIds.has(m.userId)
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

const loadAdmins = async () => {
  if (!props.roomId) return
  loading.value = true
  try {
    const resp = await GroupApi.listAdmins({ roomId: props.roomId })
    if (resp.success && resp.data) {
      admins.value = resp.data
    }
  } catch (error) {
    console.error('加载管理员列表失败:', error)
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('close')
}

const handleAddAdmin = () => {
  showAddDialog.value = true
}

const handleConfirmAddAdmin = async (selectedIds: string[]) => {
  if (selectedIds.length === 0) return

  let successCount = 0
  for (const userId of selectedIds) {
    try {
      const resp = await GroupApi.appointAdmin({
        roomId: props.roomId,
        userId,
        role: 'admin'
      })
      if (resp.success) {
        successCount++
      }
    } catch (error) {
      console.error('添加管理员失败:', error)
    }
  }

  if (successCount > 0) {
    showToast(`成功添加 ${successCount} 名管理员`)
    await loadAdmins()
    emit('updated')
  }
  showAddDialog.value = false
}

const handleRemoveAdmin = (admin: GroupAdmin) => {
  pendingRemoveAdmin.value = admin
  showRemoveConfirm.value = true
}

const confirmRemoveAdmin = async () => {
  if (!pendingRemoveAdmin.value) return

  try {
    const resp = await GroupApi.removeAdmin({
      roomId: props.roomId,
      adminId: pendingRemoveAdmin.value.adminId
    })
    if (resp.success) {
      showToast('已撤销管理员权限')
      await loadAdmins()
      emit('updated')
    } else {
      showToast(resp.message || '撤销失败')
    }
  } catch (error) {
    console.error('撤销管理员失败:', error)
    showToast('撤销失败')
  }

  pendingRemoveAdmin.value = null
  showRemoveConfirm.value = false
}

watch(() => props.visible, (visible) => {
  if (visible) {
    loadAdmins()
  }
})
</script>

<style lang="scss" scoped>
.admin-dialog-content {
  padding: 0 4px;
}

.section {
  margin-bottom: 16px;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.section-title {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.section-action {
  font-size: 13px;
  color: #1890ff;
  cursor: pointer;

  &:hover {
    opacity: 0.8;
  }
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 24px;
  color: #999;
  font-size: 14px;
}

.admin-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.admin-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #f5f5f5;
  border-radius: 8px;
}

.admin-info {
  flex: 1;
  min-width: 0;
}

.admin-name {
  font-size: 14px;
  font-weight: 500;
  color: #333;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.admin-role {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.admin-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  font-size: 13px;
  color: #1890ff;
  cursor: pointer;

  &:hover {
    opacity: 0.8;
  }

  &.danger {
    color: #ff4757;
  }
}
</style>
