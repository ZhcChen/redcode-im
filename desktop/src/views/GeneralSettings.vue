<template>
  <div class="general-settings-page">
    <header class="settings-toolbar">
      <ToolbarButton variant="back" @click="handleBack">
        <img :src="backIcon" alt="返回" />
        <span>返回</span>
      </ToolbarButton>
      <div class="toolbar-title">通用设置</div>
    </header>

    <ScrollContainer class="settings-body">
      <div class="settings-body-wrapper">
        <!-- 下载位置设置 -->
        <div class="settings-section">
          <div class="settings-item">
            <div class="settings-item-label">下载位置</div>
            <div class="settings-item-value">{{ downloadDir }}</div>
            <div class="settings-item-actions">
              <button class="settings-item-action reset-btn" @click="handleResetDownloadDir" :disabled="isResetting">
                {{ isResetting ? '重置中...' : '重置' }}
              </button>
              <button class="settings-item-action" @click="showChangeDialog = true">
                更改
              </button>
            </div>
          </div>
          <div class="settings-item-hint">
            文件下载将保存到此目录
          </div>
        </div>

        <!-- 隐私协议设置 -->
        <div class="settings-section">
          <div class="settings-item">
            <div class="settings-item-label">隐私协议</div>
            <div class="settings-item-value">查看应用隐私协议</div>
            <div class="settings-item-actions">
              <button class="settings-item-action" @click="handleViewPrivacy">
                查看
              </button>
            </div>
          </div>
          <div class="settings-item-hint">
            了解我们如何保护您的隐私和数据安全
          </div>
        </div>

        <!-- 用户协议设置 -->
        <div class="settings-section">
          <div class="settings-item">
            <div class="settings-item-label">用户协议</div>
            <div class="settings-item-value">查看应用使用条款</div>
            <div class="settings-item-actions">
              <button class="settings-item-action" @click="handleViewUserAgreement">
                查看
              </button>
            </div>
          </div>
          <div class="settings-item-hint">
            阅读使用我们的服务需要遵守的条款和条件
          </div>
        </div>
      </div>
    </ScrollContainer>

    <!-- 修改下载位置对话框 -->
    <Dialog
      v-model="showChangeDialog"
      title="修改下载位置"
      @confirm="handleConfirmChangeDir"
      @cancel="handleCancelChangeDir"
      :confirm-text="isChanging ? '保存中...' : '确定'"
      :confirm-disabled="isChanging || !newDownloadDir.trim()"
    >
      <div class="change-dir-content">
        <DialogInput
          v-model="newDownloadDir"
          placeholder="请输入下载目录路径..."
          :disabled="isChanging"
          @keyup.enter="handleConfirmChangeDir"
        />
        <div class="change-dir-hint">
          请输入完整的目录路径，例如：/Users/username/Downloads
        </div>
      </div>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
import { getDownloadDir, setDownloadDir, getChatlyDownloadDir } from '../utils/download-settings'
import { toast } from '../utils/toast'
import backIcon from '../assets/image/icon-back.svg'
import ToolbarButton from '../components/ToolbarButton.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import ScrollContainer from '../components/ScrollContainer.vue'

// Props: 接收账号ID（可选，用于多实例页面架构）
interface Props {
  accountId?: string
}

const props = withDefaults(defineProps<Props>(), {
  accountId: undefined
})

const router = useRouter()
const store = useStore()
const downloadDir = ref<string>('')
const showChangeDialog = ref(false)
const newDownloadDir = ref('')
const isChanging = ref(false)
const isResetting = ref(false)

const loadDownloadDir = async () => {
  try {
    downloadDir.value = await getDownloadDir()
  } catch (error: any) {
    console.error('加载下载目录失败:', error)
    toast.error('加载下载目录失败')
  }
}

const handleBack = () => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/settings',
        name: 'Settings',
        params: {},
        query: {}
      }
    })
  } else {
    // 否则使用全局路由
    router.push('/home/settings')
  }
}

const handleConfirmChangeDir = async () => {
  const dir = newDownloadDir.value.trim()
  if (!dir) {
    toast.error('请输入下载目录路径')
    return
  }

  isChanging.value = true
  try {
    // 验证目录是否存在
    const { invoke } = await import('@tauri-apps/api/core')
    const exists = await invoke<boolean>('check_dir_exists', { path: dir })
    
    if (!exists) {
      toast.error('目录不存在，请检查路径是否正确')
      isChanging.value = false
      return
    }

    // 保存目录
    await setDownloadDir(dir)
    downloadDir.value = dir
    showChangeDialog.value = false
    newDownloadDir.value = ''
    toast.success('下载位置已更新')
  } catch (error: any) {
    console.error('修改下载目录失败:', error)
    toast.error('修改下载目录失败: ' + (error?.message || '未知错误'))
  } finally {
    isChanging.value = false
  }
}

const handleCancelChangeDir = () => {
  showChangeDialog.value = false
  newDownloadDir.value = ''
}

const handleChangeDownloadDir = () => {
  newDownloadDir.value = downloadDir.value
  showChangeDialog.value = true
}

const handleResetDownloadDir = async () => {
  isResetting.value = true
  try {
    // 获取默认的 Chatly 下载目录
    const defaultDir = await getChatlyDownloadDir()
    
    // 保存为新的下载目录
    await setDownloadDir(defaultDir)
    downloadDir.value = defaultDir
    
    toast.success('已重置为默认下载位置')
  } catch (error: any) {
    console.error('重置下载目录失败:', error)
    toast.error('重置下载目录失败: ' + (error?.message || '未知错误'))
  } finally {
    isResetting.value = false
  }
}

// 处理查看隐私协议
const handleViewPrivacy = async () => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/privacy',
        name: 'Privacy',
        params: { type: 'privacy' },
        query: {}
      }
    })
  } else {
    // 否则使用全局路由
    try {
      await router.push('/home/privacy?type=privacy')
    } catch (error: any) {
      toast.error('暂时无法打开隐私协议，请稍后重试')
    }
  }
}

// 处理查看用户协议
const handleViewUserAgreement = async () => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/privacy',
        name: 'Privacy',
        params: { type: 'user-agreement' },
        query: {}
      }
    })
  } else {
    // 否则使用全局路由
    try {
      await router.push('/home/privacy?type=user-agreement')
    } catch (error: any) {
      toast.error('暂时无法打开用户协议，请稍后重试')
    }
  }
}

onMounted(() => {
  loadDownloadDir()
})
</script>

<style lang="scss" scoped>
.general-settings-page {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  background: $bg-chat;
}

.settings-toolbar {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px 32px;
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
}

.toolbar-title {
  font-size: 20px;
  font-weight: 600;
  color: #111827;
}


.settings-body {
  flex: 1;
}

.settings-body-wrapper {
  min-height: 100%;
  padding: 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.settings-section {
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  margin-bottom: 16px;
  width: 100%;
  max-width: 700px;
}

.settings-item {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 8px;
}

.settings-item-label {
  font-size: 16px;
  font-weight: 500;
  color: #111827;
  min-width: 100px;
}

.settings-item-value {
  flex: 1;
  font-size: 14px;
  color: #6b7280;
  word-break: break-all;
}

.settings-item-actions {
  display: flex;
  gap: 8px;
  align-items: center;
}

.settings-item-action {
  padding: 8px 16px;
  border: 1px solid #d1d5db;
  background: #fff;
  color: #374151;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.2s;
  white-space: nowrap;

  &:hover:not(:disabled) {
    background: #f9fafb;
    border-color: #9ca3af;
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.reset-btn {
  color: #6b7280;
  border-color: #e5e7eb;

  &:hover:not(:disabled) {
    background: #f3f4f6;
    border-color: #d1d5db;
  }
}

.settings-item-hint {
  font-size: 13px;
  color: #9ca3af;
  margin-top: 8px;
  padding-left: 116px;
}

.change-dir-content {
  padding: 16px 8px;
}

.change-dir-hint {
  margin-top: 12px;
  font-size: 13px;
  color: #9ca3af;
  line-height: 1.5;
}
</style>

