<template>
  <div class="account-tabs">
    <div class="tabs-container">
      <!-- 账号标签列表 -->
      <div
        v-for="(account, index) in accounts"
        :key="account.id"
        :data-account-id="account.id"
        :data-index="index"
        class="account-tab"
        :class="{ 
          active: account.id === currentAccountId,
          'has-unread': hasUnreadMessages(account),
          'dragging': draggedAccountId === account.id,
          'drag-over': dragOverAccountId === account.id
        }"
        role="button"
        tabindex="0"
        @click.stop="handleSwitchAccount(account.id)"
        @mousedown="handleMouseDown($event, account.id, index)"
      >
        <div class="tab-content">
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
import { ref, watch } from 'vue'
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
const dragStartIndex = ref<number>(-1)
const dragStartX = ref<number>(0)
const dragStartY = ref<number>(0)

// 检查账号是否有未读消息（消息未读数 + 好友申请未读数）
function hasUnreadMessages(account: AccountInfo): boolean {
  return getUnreadCount(account) > 0
}

// 获取账号的未读总数（消息未读数 + 好友申请未读数）
function getUnreadCount(account: AccountInfo): number {
  const messageUnread = account.unreadCount || 0
  const friendRequestUnread = account.friendRequestCount || 0
  return messageUnread + friendRequestUnread
}

// 格式化角标数字显示
function formatBadgeCount(count: number): string {
  if (count > 99) {
    return '99+'
  }
  return count.toString()
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

// 鼠标按下开始拖拽
function handleMouseDown(event: MouseEvent, accountId: string, index: number) {
  // 如果点击的是关闭按钮，不触发拖拽
  if ((event.target as HTMLElement).closest('.close-btn')) {
    return
  }

  // 记录初始位置
  dragStartX.value = event.clientX
  dragStartY.value = event.clientY
  dragStartIndex.value = index
  draggedAccountId.value = accountId
  isDragging.value = false // 先设为 false，移动一定距离后才算拖拽

  console.log('🖱️ 鼠标按下:', { accountId, index, x: dragStartX.value, y: dragStartY.value })

  // 添加全局事件监听
  document.addEventListener('mousemove', handleMouseMove)
  document.addEventListener('mouseup', handleMouseUp)

  // 阻止默认行为
  event.preventDefault()
}

// 鼠标移动
function handleMouseMove(event: MouseEvent) {
  if (!draggedAccountId.value) return

  const deltaX = Math.abs(event.clientX - dragStartX.value)
  const deltaY = Math.abs(event.clientY - dragStartY.value)

  // 移动超过 5px 才算拖拽
  if (!isDragging.value && (deltaX > 5 || deltaY > 5)) {
    isDragging.value = true
    console.log('🚀 开始拖拽账号:', draggedAccountId.value)
    // 设置全局光标样式
    document.body.style.cursor = 'grabbing'
  }

  if (!isDragging.value) return

  // 查找鼠标下方的元素
  const elementBelow = document.elementFromPoint(event.clientX, event.clientY)
  if (!elementBelow) {
    dragOverAccountId.value = null
    return
  }

  // 查找最近的 account-tab 元素
  const tabElement = elementBelow.closest('.account-tab') as HTMLElement
  if (!tabElement) {
    dragOverAccountId.value = null
    return
  }

  const targetAccountId = tabElement.dataset.accountId
  if (targetAccountId && targetAccountId !== draggedAccountId.value) {
    dragOverAccountId.value = targetAccountId
  } else {
    dragOverAccountId.value = null
  }
}

// 鼠标释放完成拖拽
async function handleMouseUp(event: MouseEvent) {
  // 移除全局事件监听
  document.removeEventListener('mousemove', handleMouseMove)
  document.removeEventListener('mouseup', handleMouseUp)

  if (!isDragging.value || !draggedAccountId.value) {
    // 如果没有拖拽，可能是点击，重置状态
    draggedAccountId.value = null
    dragOverAccountId.value = null
    dragStartIndex.value = -1
    return
  }

  console.log('🎯 鼠标释放，完成拖拽')

  // 查找鼠标下方的元素
  const elementBelow = document.elementFromPoint(event.clientX, event.clientY)
  if (!elementBelow) {
    resetDragState()
    return
  }

  const tabElement = elementBelow.closest('.account-tab') as HTMLElement
  if (!tabElement) {
    resetDragState()
    return
  }

  const targetAccountId = tabElement.dataset.accountId
  const targetIndex = parseInt(tabElement.dataset.index || '-1')

  console.log('🎯 放置账号:', { 
    targetAccountId, 
    targetIndex,
    draggedAccountId: draggedAccountId.value,
    dragStartIndex: dragStartIndex.value
  })

  const sourceAccountId = draggedAccountId.value
  if (!sourceAccountId || !targetAccountId || sourceAccountId === targetAccountId) {
    console.log('ℹ️ 跳过放置: 源账号和目标账号相同或无效')
    resetDragState()
    return
  }

  // 获取当前账号顺序
  const currentOrder = props.accounts.map(acc => acc.id)
  const sourceIndex = currentOrder.indexOf(sourceAccountId)
  const finalTargetIndex = targetIndex >= 0 ? targetIndex : currentOrder.indexOf(targetAccountId)

  console.log('📊 当前顺序:', currentOrder)
  console.log('📍 源索引:', sourceIndex, '目标索引:', finalTargetIndex)

  if (sourceIndex === -1 || finalTargetIndex === -1) {
    console.error('❌ 索引无效:', { sourceIndex, finalTargetIndex })
    resetDragState()
    return
  }

  // 重新排序
  const newOrder = [...currentOrder]
  newOrder.splice(sourceIndex, 1)
  newOrder.splice(finalTargetIndex, 0, sourceAccountId)

  console.log('🔄 新顺序:', newOrder)

  resetDragState()

  try {
    console.log('💾 开始保存账号顺序...')
    // 调用 store action 保存顺序
    await store.dispatch('accounts/reorderAccounts', newOrder)
    console.log('✅ 账号顺序已更新成功')
  } catch (error) {
    console.error('❌ 重新排序账号失败:', error)
  }
}

// 重置拖拽状态
function resetDragState() {
  isDragging.value = false
  draggedAccountId.value = null
  dragOverAccountId.value = null
  dragStartIndex.value = -1
  // 恢复光标样式
  document.body.style.cursor = ''
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
  cursor: grab; // 拖拽时显示抓取光标
  transition: all 0.15s ease;
  color: inherit;
  font: inherit;
  display: flex;
  align-items: center;
  position: relative;
  user-select: none; // 防止拖拽时选中文本

  &:active {
    cursor: grabbing; // 按下时显示抓取中光标
  }

  &:hover:not(.dragging):not(.drag-over) {
    background: rgba(0, 194, 179, 0.08);
  }

  &.active {
    background: #00c2b3;
    border-bottom-color: #00c2b3;
    cursor: pointer; // 激活状态使用指针光标

    &:hover:not(.dragging):not(.drag-over) {
      background: #00c2b3;
    }

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
    opacity: 0.4;
    transform: scale(0.95);
    cursor: grabbing !important;
    z-index: 1000;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    background: rgba(0, 194, 179, 0.2) !important;
  }

  &.drag-over {
    background: rgba(0, 194, 179, 0.25) !important;
    border-left: 3px solid #00c2b3;
    border-right: 3px solid #00c2b3;
    transform: scale(1.05);
    box-shadow: 0 2px 8px rgba(0, 194, 179, 0.3);
    position: relative;
    
    &::before {
      content: '';
      position: absolute;
      left: -3px;
      top: 0;
      bottom: 0;
      width: 3px;
      background: #00c2b3;
      animation: pulse-border 1s ease-in-out infinite;
    }
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

// 拖拽插入指示线动画
@keyframes pulse-border {
  0%, 100% {
    opacity: 1;
    transform: scaleY(1);
  }
  50% {
    opacity: 0.6;
    transform: scaleY(0.95);
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

.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 6px;
  background: #ff4757;
  color: #fff;
  border-radius: 9px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1;
  flex-shrink: 0;
  box-shadow: 0 2px 4px rgba(255, 71, 87, 0.3);
  
  // 激活状态下的角标样式
  .account-tab.active & {
    background: #fff;
    color: #00c2b3;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
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
