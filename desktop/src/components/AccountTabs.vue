<template>
  <div class="account-tabs">
    <div class="tabs-container">
      <!-- 账号标签列表 -->
      <div
        v-for="account in accounts"
        :key="account.id"
        class="account-tab"
        :class="{ 
          active: account.id === currentAccountId,
          'has-unread': hasUnreadMessages(account),
          'dragging': draggedAccountId === account.id,
          'drag-over': dragOverAccountId === account.id
        }"
        role="button"
        tabindex="0"
        draggable="true"
        @click.stop="handleSwitchAccount(account.id)"
        @dragstart="handleDragStart($event, account.id)"
        @dragend="handleDragEnd"
        @dragover.prevent.stop="handleDragOver($event, account.id)"
        @dragenter.prevent="handleDragEnter($event, account.id)"
        @dragleave="handleDragLeave($event, account.id)"
        @drop.prevent.stop="handleDrop($event, account.id)"
      >
        <div 
          class="tab-content"
          @dragover.prevent
        >
          <!-- 昵称 -->
          <span class="nickname">{{ account.userInfo.nickname || '未命名' }}</span>

          <!-- 关闭按钮 -->
          <button
            v-if="accounts.length > 1"
            class="close-btn"
            @click.stop="handleRemoveAccount(account.id)"
            title="退出登录"
            type="button"
          >
            ×
          </button>
        </div>
      </div>

      <!-- 添加账号按钮 -->
      <button
        v-if="showAddButton && accounts.length < maxAccounts"
        class="add-account-btn"
        @click="handleAddAccount"
        title="添加账号"
      >
        <span class="add-icon">+</span>
        <span class="add-text">添加账号</span>
      </button>

      <!-- 账号数量限制提示 -->
      <div v-else-if="showAddButton" class="max-accounts-tip">
        最多支持 {{ maxAccounts }} 个账号
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useStore } from 'vuex'
import type { AccountInfo } from '@/store/modules/accounts'

// Props
interface Props {
  accounts: AccountInfo[]
  currentAccountId: string | null
  maxAccounts?: number
  showAddButton?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  maxAccounts: 10,
  showAddButton: true
})

// Emits
const emit = defineEmits<{
  (e: 'switch', accountId: string): void
  (e: 'add'): void
  (e: 'remove', accountId: string): void
}>()

const store = useStore()

// 拖拽相关状态
const draggedAccountId = ref<string | null>(null)
const dragOverAccountId = ref<string | null>(null)
const isDragging = ref(false)

// 检查账号是否有未读消息（消息未读数 + 好友申请未读数）
function hasUnreadMessages(account: AccountInfo): boolean {
  // 如果是当前账号，检查好友申请数量
  if (account.id === props.currentAccountId) {
    const pendingFriendRequests = store.getters.pendingFriendRequests || 0
    return account.unreadCount > 0 || pendingFriendRequests > 0
  }
  // 非当前账号只检查消息未读数
  return account.unreadCount > 0
}

// 切换账号
function handleSwitchAccount(accountId: string) {
  // 如果正在拖拽，不触发切换
  if (isDragging.value) {
    return
  }
  if (accountId !== props.currentAccountId) {
    emit('switch', accountId)
  }
}

// 添加账号
function handleAddAccount() {
  emit('add')
}

// 移除账号
function handleRemoveAccount(accountId: string) {
  emit('remove', accountId)
}

// 拖拽开始
function handleDragStart(event: DragEvent, accountId: string) {
  console.log('🚀 开始拖拽账号:', accountId)
  isDragging.value = true
  draggedAccountId.value = accountId
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', accountId)
    // 设置拖拽图像
    if (event.target instanceof HTMLElement) {
      event.dataTransfer.setDragImage(event.target, 0, 0)
      event.target.style.opacity = '0.5'
    }
  }
}

// 拖拽结束
function handleDragEnd(event: DragEvent) {
  console.log('拖拽结束')
  // 如果已经处理过 drop，这里不需要再处理
  if (!isDragging.value) {
    return
  }
  // 延迟重置，确保 drop 事件先执行
  setTimeout(() => {
    isDragging.value = false
    draggedAccountId.value = null
    dragOverAccountId.value = null
  }, 100)
  // 恢复样式
  if (event.target instanceof HTMLElement) {
    event.target.style.opacity = '1'
  }
}

// 拖拽悬停
function handleDragOver(event: DragEvent, accountId: string) {
  event.preventDefault()
  event.stopPropagation()
  
  if (draggedAccountId.value && draggedAccountId.value !== accountId) {
    dragOverAccountId.value = accountId
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = 'move'
    }
  }
}

// 拖拽进入
function handleDragEnter(event: DragEvent, accountId: string) {
  event.preventDefault()
  if (draggedAccountId.value && draggedAccountId.value !== accountId) {
    dragOverAccountId.value = accountId
  }
}

// 拖拽离开
function handleDragLeave(event: DragEvent, accountId: string) {
  // 只有当真正离开元素时才清除 drag-over 状态
  // 检查 relatedTarget 是否是当前元素的子元素
  const relatedTarget = event.relatedTarget as HTMLElement | null
  if (relatedTarget && event.currentTarget instanceof HTMLElement) {
    if (event.currentTarget.contains(relatedTarget)) {
      return // 仍在元素内部，不处理
    }
  }
  
  if (dragOverAccountId.value === accountId) {
    dragOverAccountId.value = null
  }
}

// 放置
async function handleDrop(event: DragEvent, targetAccountId: string) {
  event.preventDefault()
  event.stopPropagation()
  
  console.log('🎯 放置账号事件触发:', { 
    targetAccountId, 
    draggedAccountId: draggedAccountId.value,
    eventType: event.type,
    timestamp: Date.now()
  })
  
  const sourceAccountId = draggedAccountId.value
  if (!sourceAccountId) {
    console.warn('⚠️ 源账号ID为空')
    dragOverAccountId.value = null
    isDragging.value = false
    return
  }
  
  if (sourceAccountId === targetAccountId) {
    console.log('ℹ️ 跳过放置: 源账号和目标账号相同')
    dragOverAccountId.value = null
    isDragging.value = false
    draggedAccountId.value = null
    return
  }

  // 获取当前账号顺序
  const currentOrder = props.accounts.map(acc => acc.id)
  const sourceIndex = currentOrder.indexOf(sourceAccountId)
  const targetIndex = currentOrder.indexOf(targetAccountId)

  console.log('📊 当前顺序:', currentOrder)
  console.log('📍 源索引:', sourceIndex, '目标索引:', targetIndex)

  if (sourceIndex === -1 || targetIndex === -1) {
    console.error('❌ 索引无效:', { sourceIndex, targetIndex })
    dragOverAccountId.value = null
    isDragging.value = false
    draggedAccountId.value = null
    return
  }

  // 重新排序
  const newOrder = [...currentOrder]
  newOrder.splice(sourceIndex, 1)
  newOrder.splice(targetIndex, 0, sourceAccountId)

  console.log('🔄 新顺序:', newOrder)

  // 先清空拖拽状态，避免 dragend 事件再次清空
  isDragging.value = false
  draggedAccountId.value = null
  dragOverAccountId.value = null

  try {
    console.log('💾 开始保存账号顺序...')
    // 调用 store action 保存顺序
    await store.dispatch('accounts/reorderAccounts', newOrder)
    console.log('✅ 账号顺序已更新成功')
  } catch (error) {
    console.error('❌ 重新排序账号失败:', error)
    // 恢复状态以便重试
    draggedAccountId.value = sourceAccountId
    isDragging.value = true
  }
}
</script>

<style scoped lang="scss">
.account-tabs {
  width: 100%;
  padding: 0;
  box-sizing: border-box;
}

.tabs-container {
  display: flex;
  align-items: stretch;
  gap: 6px;
  overflow-x: auto;
  overflow-y: hidden;
  height: 42px;

  &::-webkit-scrollbar {
    height: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: #00c2b3;
    border-radius: 2px;
  }

  &::-webkit-scrollbar-track {
    background: transparent;
  }
}

.account-tab {
  flex-shrink: 0;
  min-width: 110px;
  max-width: 200px;
  height: 100%;
  border: none;
  border-bottom: 2px solid transparent;
  background: transparent;
  padding: 0 12px;
  cursor: move; // 拖拽时显示移动光标
  transition: all 0.2s ease;
  color: inherit;
  font: inherit;
  display: flex;
  align-items: center;
  position: relative;
  user-select: none; // 防止拖拽时选中文本

  &:hover {
    background: rgba(0, 194, 179, 0.08);
  }

  &.active {
    background: #00c2b3;
    border-bottom-color: #00c2b3;
    cursor: pointer; // 激活状态使用指针光标

    .tab-content {
      .nickname {
        color: #fff;
        font-weight: 600;
      }

      .close-btn {
        color: #fff;

        &:hover {
          background: rgba(255, 255, 255, 0.2);
        }
      }
    }
  }

  // 有未读消息时的闪烁效果
  &.has-unread:not(.active) {
    animation: blink-orange 1.5s ease-in-out infinite;
  }

  // 拖拽状态样式
  &.dragging {
    opacity: 0.5;
  }

  &.drag-over {
    background: rgba(0, 194, 179, 0.15);
    border-left: 2px solid #00c2b3;
  }
}

// 橙色背景闪烁动画
@keyframes blink-orange {
  0%, 100% {
    background-color: rgba(255, 152, 0, 0.15);
  }
  50% {
    background-color: rgba(255, 152, 0, 0.35);
  }
}

.tab-content {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  height: 100%;
}
.nickname {
  flex: 1;
  font-size: 12px;
  color: var(--text-primary, #334155);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 500;
}

.close-btn {
  border: none;
  background: transparent;
  color: #94a3b8;
  font-size: 14px;
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
  transition: all 0.2s ease;

  &:hover {
    background: rgba(148, 163, 184, 0.25);
    color: #0f172a;
  }
}

.add-account-btn {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 32px;
  padding: 0 12px;
  border: 1px dashed #00c2b3;
  border-radius: 16px;
  background: rgba(0, 194, 179, 0.12);
  color: #006d65;
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 12px;

  &:hover {
    background: rgba(0, 194, 179, 0.18);
    border-style: solid;
  }

  .add-icon {
    font-size: 16px;
    font-weight: 600;
  }

  .add-text {
    font-weight: 500;
  }
}

.max-accounts-tip {
  flex-shrink: 0;
  padding: 10px 16px;
  color: #94a3b8;
  font-size: 12px;
  white-space: nowrap;
}
</style>
