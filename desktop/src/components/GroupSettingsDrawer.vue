<template>
  <div class="group-settings-drawer" :class="{ 'group-settings-drawer--visible': visible }" @click="handleMaskClick">
    <!-- 抽屉内容 -->
    <ScrollContainer
      class="drawer-content"
      @click.stop
    >
      <!-- 第一行：标题栏 -->
      <div class="drawer-header">
        <img
          src="@/assets/image/icon-menu.svg"
          alt="群设置"
          class="header-icon"
          @click="handleClose"
        />
        <div class="header-title">{{ groupInfo?.groupType === 1 ? '群设置' : '聊天设置' }}</div>
      </div>

      <!-- 第二行：群成员管理（仅群聊显示） -->
      <div class="drawer-section" v-if="groupInfo?.groupType === 1">
        <div class="member-grid">
          <!-- 新增成员按钮 -->
          <div class="member-item add-member-btn" @click="handleAddMember">
            <div class="member-avatar add-avatar">
              <span class="add-icon">+</span>
            </div>
            <div class="member-name">添加</div>
          </div>

          <!-- 删除成员按钮 -->
          <div class="member-item remove-member-btn" @click="handleRemoveMember">
            <div class="member-avatar remove-avatar">
              <span class="remove-icon">-</span>
            </div>
            <div class="member-name">删除</div>
          </div>

          <!-- 群成员列表 -->
          <div
            v-for="member in displayMembers"
            :key="member.userId"
            class="member-item"
          >
            <Avatar
              :src="member.avatarUrl || ''"
              :text="member.nickname || member.username"
              :size="48"
            />
            <div class="member-name">{{ member.nickname || member.username }}</div>
          </div>
        </div>

        <!-- 查看更多成员 -->
        <div class="view-all-members" @click="toggleMemberExpansion">
          {{ viewAllText }}
        </div>
      </div>

      <!-- 第三行：设置选项 -->
      <div class="drawer-section">
        <!-- 群聊专属设置 -->
        <template v-if="groupInfo?.groupType === 1">
          <div class="setting-item" @click="handleEditGroupName">
            <div class="setting-label">群名称</div>
            <div class="setting-value">
              {{ groupInfo?.name || '' }}
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleEditGroupAvatar">
            <div class="setting-label">群头像</div>
            <div class="setting-value">
              <Avatar :src="groupInfo?.avatar" :text="groupInfo?.name" :size="32" />
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleEditGroupNotice">
            <div class="setting-label">群公告</div>
            <div class="setting-value">
              {{ groupNoticeText }}
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" v-if="isGroupOwner">
            <div class="setting-label">全体禁言</div>
            <div class="setting-value">
              <BSwitch
                :model-value="globalMuteEnabled ?? false"
                :disabled="globalMuteLoading"
                @change="handleGlobalMuteChange"
              />
            </div>
          </div>

          <div class="setting-item" v-if="isGroupOwner" @click="handleTransferOwner">
            <div class="setting-label">转让群主</div>
            <div class="setting-value">
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleClearHistory">
            <div class="setting-label">清除聊天记录</div>
            <div class="setting-value">
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleReport">
            <div class="setting-label">举报群聊</div>
          </div>

          <div
            class="setting-item danger"
            @click="isGroupOwner ? handleDissolveGroup() : handleLeaveGroup()"
          >
            <div class="setting-label">{{ isGroupOwner ? '解散群聊' : '退出群聊' }}</div>
          </div>
        </template>

        <!-- 单聊专属设置 -->
        <template v-else-if="groupInfo?.groupType === 0">
          <div class="setting-item" @click="handleEditRemark">
            <div class="setting-label">备注</div>
            <div class="setting-value">
              {{ remarkText }}
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleClearHistory">
            <div class="setting-label">清除聊天记录</div>
            <div class="setting-value">
              <img src="@/assets/image/icon-right.svg" alt="右箭头" class="setting-arrow" />
            </div>
          </div>

          <div class="setting-item" @click="handleReport">
            <div class="setting-label">举报用户</div>
          </div>
        </template>

        <!-- 通用设置（群聊和单聊都有） -->
        <div class="setting-item">
          <div class="setting-label">消息免打扰</div>
          <div class="setting-value">
            <BSwitch v-model="muteNotification" @change="handleMuteChange" />
          </div>
        </div>

        <div class="setting-item">
          <div class="setting-label">置顶聊天</div>
          <div class="setting-value">
            <BSwitch v-model="isTop" @change="handleTopChange" />
          </div>
        </div>
      </div>
    </ScrollContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import ScrollContainer from './ScrollContainer.vue'
import Avatar from './Avatar.vue'
import BSwitch from './BSwitch.vue'
import type { RoomMember } from '@/types/models'

interface GroupInfo {
  id: string
  roomId: string
  name: string
  avatar?: string | null
  memberCount?: number
  groupType: number
  isTop?: boolean
  chatStatus?: number
  groupNotice?: string | null
  showNoticeFlag?: boolean
  remark?: string | null
}

interface Props {
  visible: boolean
  groupInfo?: GroupInfo | null
  groupMembers?: RoomMember[]
  isGroupOwner?: boolean
  globalMuteEnabled?: boolean
  globalMuteLoading?: boolean
}

interface Emits {
  (e: 'close'): void
  (e: 'edit-group-name'): void
  (e: 'edit-group-avatar'): void
  (e: 'edit-group-notice'): void
  (e: 'edit-remark'): void
  (e: 'toggle-mute', value: boolean): void
  (e: 'toggle-top', value: boolean): void
  (e: 'add-member'): void
  (e: 'remove-member'): void
  (e: 'clear-history'): void
  (e: 'report-group'): void
  (e: 'leave-group'): void
  (e: 'toggle-global-mute', value: boolean): void
  (e: 'transfer-owner'): void
  (e: 'dissolve-group'): void
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  groupInfo: null,
  groupMembers: () => [],
  isGroupOwner: false,
  globalMuteEnabled: false,
  globalMuteLoading: false
})
const emit = defineEmits<Emits>()

// 群成员展开状态
const isExpanded = ref(false)

// 显示的成员（第一行只显示前两个，因为有新增删除按钮）
const displayMembers = computed(() => {
  if (!props.groupMembers || props.groupMembers.length === 0) {
    return []
  }

  // 展开时显示所有成员，收起时只显示前两个（第一行）
  return isExpanded.value ? props.groupMembers : props.groupMembers.slice(0, 2)
})

// 总成员数
const totalMemberCount = computed(() => props.groupMembers?.length || 0)

// 展开/收起按钮文案
const viewAllText = computed(() => {
  return isExpanded.value ? '收起' : `点击查看${totalMemberCount.value}人>`
})

// 开关状态
const muteNotification = ref(false)
const isTop = ref(false)

// 监听props变化，更新开关状态
watch(() => props.groupInfo, (newGroupInfo: GroupInfo | null | undefined) => {
  if (newGroupInfo) {
    muteNotification.value = newGroupInfo.chatStatus === 1 // 1=免打扰
    isTop.value = newGroupInfo.isTop || false
  }
}, { immediate: true })

// 计算群公告显示文本
const groupNoticeText = computed(() => {
  const groupInfo = props.groupInfo
  if (!groupInfo) return '暂无公告'

  const notice = groupInfo.groupNotice || ''
  return notice.trim().length > 0 ? notice : '暂无公告'
})

// 计算备注显示文本
const remarkText = computed(() => {
  const groupInfo = props.groupInfo
  if (!groupInfo) return '点击设置备注'

  const remark = groupInfo.remark || ''
  return remark.trim().length > 0 ? remark : '点击设置备注'
})

// 事件处理
const handleClose = () => {
  emit('close')
}

const handleMaskClick = () => {
  // 点击抽屉容器外部区域关闭抽屉
  emit('close')
}

const handleEditGroupName = () => {
  emit('edit-group-name')
}

const handleEditGroupAvatar = () => {
  emit('edit-group-avatar')
}

const handleEditGroupNotice = () => {
  emit('edit-group-notice')
}

const handleEditRemark = () => {
  emit('edit-remark')
}

const handleAddMember = () => {
  // 显示添加成员对话框
  emit('add-member')
}

const handleRemoveMember = () => {
  // 显示删除成员对话框
  emit('remove-member')
}

const handleTransferOwner = () => {
  emit('transfer-owner')
}

const handleGlobalMuteChange = (value: boolean) => {
  emit('toggle-global-mute', value)
}

const handleDissolveGroup = () => {
  emit('dissolve-group')
}

const toggleMemberExpansion = () => {
  isExpanded.value = !isExpanded.value
}

const handleViewAllMembers = () => {
  // 已合并到 toggleMemberExpansion
}

const handleMuteChange = (value: boolean) => {
  emit('toggle-mute', value)
}

const handleTopChange = (value: boolean) => {
  emit('toggle-top', value)
}

const handleClearHistory = () => {
  emit('clear-history')
}

const handleReport = () => {
  emit('report-group')
}

const handleLeaveGroup = () => {
  emit('leave-group')
}
</script>

<style lang="scss" scoped>
.group-settings-drawer {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
  background-color: transparent; /* 透明遮罩 */
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.3s ease, visibility 0.3s ease;

  &--visible {
    opacity: 1;
    visibility: visible;

    .drawer-content {
      transform: translateX(0);
    }
  }
}

.drawer-content {
  position: absolute;
  top: 0;
  right: 0;
  width: 348px;
  height: 100%;
  background-color: #F4F4F7;
  transform: translateX(100%);
  transition: transform 0.3s ease;
  padding: 0;
}

.drawer-header {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px 24px;
  position: relative;

  .header-icon {
    position: absolute;
    left: 24px;
    width: 24px;
    height: 24px;
    transform: rotate(90deg); /* 顺时针旋转90度 */
    transition: opacity 0.2s ease;

    &:hover {
      opacity: 0.7;
    }
  }

  .header-title {
    font-size: 17px;
    color: #000000;
    font-weight: bold;
  }
}

.drawer-section {
  background: white;
  margin: 0 24px;
  padding: 20px;
  border-radius: 16px;

  &:not(:first-child) {
    margin-top: 24px;
  }

  &:last-child {
    margin-bottom: 16px;
  }
}

.drawer-section:first-of-type {
  margin-top: 24px;
}

.drawer-section:not(:last-child) {
  margin-bottom: 0;
}

.drawer-section + .drawer-section {
  margin-top: 16px;
}

/* 群成员网格 */
.member-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;

  .member-item {
    display: flex;
    flex-direction: column;
    align-items: center;

    .member-name {
      font-size: 12px;
      color: #000000;
      margin-top: 12px;
      text-align: center;
      line-height: 1;
    }
  }

  .add-member-btn, .remove-member-btn {
    .member-avatar {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      font-weight: bold;
      color: white;
    }

    .add-avatar {
      background-color: var(--primary-color, #4ECDC4);
    }

    .remove-avatar {
      background-color: #ff4757;
    }
  }
}

.view-all-members {
  text-align: center;
  margin-top: 24px;
  font-size: 12px;
  color: #999999;

  &:hover {
    opacity: 0.7;
  }
}

/* 设置选项 */
.setting-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 0;
  transition: opacity 0.2s;

  &:not(:last-child) {
    border-bottom: 1px solid #f5f5f5;
  }

  &:hover {
    opacity: 0.7;
  }

  &.danger {
    .setting-label {
      color: #ff4757;
    }
  }

  .setting-label {
    font-size: 14px;
    color: #2C2D3A;
    font-weight: 400;
  }

  .setting-value {
    font-size: 14px;
    color: #666;
    display: flex;
    align-items: center;
    gap: 6px; /* 元素间距离6px */

    .setting-arrow {
      width: 24px;
      height: 24px;
      flex-shrink: 0;
    }
  }
}
</style>
