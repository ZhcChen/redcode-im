<template>
  <div class="account-tabs">
    <div class="tabs-container">
      <!-- 账号标签列表 -->
      <div
        v-for="account in accounts"
        :key="account.id"
        class="account-tab"
        :class="{ active: account.id === currentAccountId }"
        @click="handleSwitchAccount(account.id)"
      >
        <div class="tab-content">
          <!-- 头像 -->
          <img
            :src="account.userInfo.avatar || '/default-avatar.png'"
            class="avatar"
            :alt="account.userInfo.nickname"
          />

          <!-- 昵称 -->
          <span class="nickname">{{ account.userInfo.nickname || '未命名' }}</span>

          <!-- 未读角标 -->
          <span v-if="account.unreadCount > 0" class="badge">
            {{ account.unreadCount > 99 ? '99+' : account.unreadCount }}
          </span>

          <!-- 关闭按钮 -->
          <button
            v-if="accounts.length > 1"
            class="close-btn"
            @click.stop="handleRemoveAccount(account.id)"
            title="退出登录"
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
interface Emits {
  (e: 'switch', accountId: string): void
  (e: 'add'): void
  (e: 'remove', accountId: string): void
}

const emit = defineEmits<Emits>()

// 切换账号
function handleSwitchAccount(accountId: string) {
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
  if (confirm('确定要退出此账号吗？')) {
    emit('remove', accountId)
  }
}
</script>

<style scoped lang="scss">
.account-tabs {
  width: 100%;
  background: var(--bg-color, #ffffff);
  border-bottom: 1px solid var(--border-color, #e5e7eb);
  padding: 6px 12px;
  box-sizing: border-box;
}

.tabs-container {
  display: flex;
  align-items: center;
  gap: 8px;
  overflow-x: auto;
  overflow-y: hidden;

  /* 自定义滚动条 */
  &::-webkit-scrollbar {
    height: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: #00C2B3;
    border-radius: 2px;
  }

  &::-webkit-scrollbar-track {
    background: transparent;
  }
}

.account-tab {
  flex-shrink: 0;
  min-width: 160px;
  max-width: 200px;
  height: 40px;
  background: var(--bg-secondary, #f9fafb);
  border: 1px solid var(--border-color, #e5e7eb);
  border-radius: 6px;
  padding: 6px 10px;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: #00C2B3;
    background: var(--bg-color, #ffffff);
    box-shadow: 0 1px 4px rgba(0, 194, 179, 0.15);
  }

  &.active {
    background: #00C2B3;
    border-color: #00C2B3;
    box-shadow: 0 2px 8px rgba(0, 194, 179, 0.25);

    .tab-content {
      .nickname {
        color: #fff;
        font-weight: 600;
      }

      .badge {
        background: #ff4757;
      }

      .close-btn {
        color: #fff;

        &:hover {
          background: rgba(255, 255, 255, 0.2);
        }
      }
    }
  }
}

.tab-content {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  height: 100%;
}

.avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
}

.nickname {
  flex: 1;
  font-size: 13px;
  color: var(--text-primary, #333);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 500;
}

.badge {
  flex-shrink: 0;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  background: #f56c6c;
  color: #fff;
  font-size: 12px;
  font-weight: bold;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 4px rgba(245, 108, 108, 0.4);
}

.close-btn {
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  border: none;
  background: transparent;
  color: #999;
  font-size: 20px;
  line-height: 1;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;

  &:hover {
    background: rgba(0, 0, 0, 0.05);
    color: #f56c6c;
    transform: rotate(90deg);
  }
}

.add-account-btn {
  flex-shrink: 0;
  min-width: 100px;
  height: 40px;
  background: var(--bg-color, #ffffff);
  border: 1.5px dashed #00C2B3;
  border-radius: 6px;
  padding: 6px 12px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  color: #00C2B3;
  font-size: 13px;
  font-weight: 500;

  &:hover {
    background: rgba(0, 194, 179, 0.05);
    border-color: #00C2B3;
    box-shadow: 0 1px 4px rgba(0, 194, 179, 0.15);
  }

  .add-icon {
    font-size: 18px;
    font-weight: bold;
  }
}

.max-accounts-tip {
  flex-shrink: 0;
  padding: 12px 16px;
  color: #999;
  font-size: 12px;
  white-space: nowrap;
}
</style>
