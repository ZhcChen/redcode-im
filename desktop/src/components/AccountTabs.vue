<template>
  <div class="account-tabs">
    <div class="tabs-container">
      <!-- 账号标签列表 -->
      <div
        v-for="account in accounts"
        :key="account.id"
        class="account-tab"
        :class="{ active: account.id === currentAccountId }"
        role="button"
        tabindex="0"
        @click="handleSwitchAccount(account.id)"
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
  emit('remove', accountId)
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
  cursor: pointer;
  transition: all 0.2s ease;
  color: inherit;
  font: inherit;
  display: flex;
  align-items: center;

  &:hover {
    background: rgba(0, 194, 179, 0.08);
  }

  &.active {
    background: #00c2b3;
    border-bottom-color: #00c2b3;

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
