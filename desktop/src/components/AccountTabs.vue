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
        v-if="accounts.length < maxAccounts"
        class="add-account-btn"
        @click="handleAddAccount"
        title="添加账号"
      >
        <span class="add-icon">+</span>
        <span class="add-text">添加账号</span>
      </button>

      <!-- 账号数量限制提示 -->
      <div v-else class="max-accounts-tip">
        最多支持 {{ maxAccounts }} 个账号
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { defineProps, defineEmits } from 'vue'
import type { AccountInfo } from '@/store/modules/accounts'

// Props
interface Props {
  accounts: AccountInfo[]
  currentAccountId: string | null
  maxAccounts?: number
}

const props = withDefaults(defineProps<Props>(), {
  maxAccounts: 10
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
  background: #f5f5f5;
  border-bottom: 1px solid #e0e0e0;
  padding: 8px 12px;
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
    background: #ccc;
    border-radius: 2px;
  }

  &::-webkit-scrollbar-track {
    background: transparent;
  }
}

.account-tab {
  flex-shrink: 0;
  min-width: 180px;
  max-width: 220px;
  height: 48px;
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 8px 12px;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    border-color: #409eff;
    transform: translateY(-2px);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  &.active {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-color: #667eea;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);

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
  width: 32px;
  height: 32px;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
  border: 2px solid rgba(255, 255, 255, 0.3);
}

.nickname {
  flex: 1;
  font-size: 14px;
  color: #333;
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
  min-width: 120px;
  height: 48px;
  background: #fff;
  border: 2px dashed #409eff;
  border-radius: 8px;
  padding: 8px 16px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: #409eff;
  font-size: 14px;
  font-weight: 500;

  &:hover {
    background: #ecf5ff;
    border-color: #66b1ff;
    transform: translateY(-2px);
    box-shadow: 0 2px 8px rgba(64, 158, 255, 0.2);
  }

  .add-icon {
    font-size: 20px;
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
