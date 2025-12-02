<template>
  <ScrollContainer class="settings">
    <div class="settings-wrapper">
    <!-- 头像模块 -->
    <div class="settings-section avatar-section">
      <div class="avatar-container">
        <div class="avatar-wrapper" @click="handleChangeAvatar">
          <Avatar 
            :src="userAvatarLocalPath" 
            :text="userDisplayName"
            :color-seed="currentUser.id"
            :alt="userDisplayName + '的头像'" 
            :size="100" 
          />
          <img 
            :src="editIcon" 
            alt="编辑头像" 
            class="avatar-edit-icon"
          />
        </div>

      </div>
    </div>

    <!-- 用户名模块 -->
    <div class="settings-section username-section">
      <div class="username-container">
        <div class="username-display">{{ userDisplayName }}</div>
        <img 
          :src="penIcon" 
          alt="编辑用户名" 
          class="username-edit-icon"
          @click="handleEditUsername"
        />
      </div>
    </div>

    <!-- 手机号模块 -->
    <div class="settings-section phone-section">
      <div class="phone-display">
        <span class="phone-label">手机号：</span>
        <span class="phone-value">{{ currentUser.mobile || '未绑定' }}</span>
      </div>
    </div>

    <!-- 版本更新模块 -->
    <div class="settings-section version-section">
      <div class="version-container">
        <div class="version-info">
          <div class="version-title">桌面端版本</div>
          <div class="version-detail">
            当前：v{{ currentVersionInfo.version }}
            <span v-if="hasUpdate && latestVersion" class="version-tag">
              最新：v{{ latestVersion.version }}
            </span>
          </div>
          <div v-if="latestVersion?.release_notes" class="version-notes">
            {{ latestVersion.release_notes }}
          </div>
        </div>
        <div class="version-actions">
          <button
            class="version-btn"
            :disabled="checkingUpdate"
            @click="handleCheckUpdate"
          >
            {{ checkingUpdate ? '检查中...' : '检查更新' }}
          </button>
          <button
            v-if="hasUpdate && latestVersion"
            class="version-btn primary"
            :disabled="downloadInProgress"
            @click="handleDownloadUpdate"
          >
            {{ downloadInProgress ? '下载中...' : '下载更新' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 通用设置模块 -->
    <div class="settings-section general-section">
      <div class="privacy-container" @click.stop.prevent="handleViewGeneral">
        <div class="privacy-text">通用</div>
        <img 
          :src="rightIcon" 
          alt="查看" 
          class="privacy-icon"
        />
      </div>
    </div>


    <!-- 关于模块 -->
    <div class="settings-section about-section">
      <div class="privacy-container" @click.stop="showAboutDialog = true">
        <div class="privacy-text">关于 Chatly</div>
        <img 
          :src="rightIcon" 
          alt="查看" 
          class="privacy-icon"
        />
      </div>
    </div>

    <!-- 退出登录模块 -->
    <div class="settings-section logout-section">
      <button class="logout-btn" @click="handleLogout">
        <img 
          :src="logoutIcon" 
          alt="退出登录" 
          class="logout-icon"
        />
        <span class="logout-text">退出登录</span>
      </button>
    </div>

    <!-- 修改昵称对话框 -->
    <Dialog 
      v-model="showNicknameDialog" 
      title="修改昵称" 
      @confirm="handleConfirmUpdateNickname"
      @cancel="handleCancelUpdateNickname"
      :confirm-text="isUpdatingNickname ? '修改中...' : '确定'"
      :confirm-disabled="isUpdatingNickname || !newNickname.trim()"
    >
      <div class="edit-nickname-content">
        <DialogInput 
          v-model="newNickname"
          placeholder="请输入昵称..."
          :disabled="isUpdatingNickname"
          maxlength="20"
          @keyup.enter="handleConfirmUpdateNickname"
        />
        
        <!-- 错误提示 -->
        <div v-if="nicknameError" class="nickname-error">
          {{ nicknameError }}
        </div>
      </div>
    </Dialog>

    <!-- 关于对话框 -->
    <Dialog
      v-model="showAboutDialog"
      title="关于 Chatly"
      :show-footer="false"
    >
      <div class="about-dialog-content">
        <p>版本：v{{ currentVersionInfo.version }}</p>
        <p>构建号：{{ currentVersionInfo.buildNumber }}</p>
        <p>渠道：{{ currentVersionInfo.channel }}</p>
      </div>
    </Dialog>
    </div>
  </ScrollContainer>
</template>

<script setup lang="ts">
import { computed, ref, watch, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
import ScrollContainer from '../components/ScrollContainer.vue'
import Avatar from '../components/Avatar.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import { FileApi } from '../api/file'
import { UserApi } from '../api/user'
import { toast } from '../utils/toast'
import rightIcon from '../assets/image/icon/right.svg'
import logoutIcon from '../assets/image/icon-logout-red.svg'
import editIcon from '../assets/image/icon-edit.svg'
import penIcon from '../assets/image/icon-pen.svg'

// Props: 接收账号ID（可选，用于多实例页面架构）
interface Props {
  accountId?: string
}

const props = withDefaults(defineProps<Props>(), {
  accountId: undefined
})

const router = useRouter()
const store = useStore()

// 图片预览状态
const previewImageUrl = ref<string>('')
const downloadInProgress = ref(false)
const showAboutDialog = ref(false)

// 昵称修改相关状态
const showNicknameDialog = ref(false)
const newNickname = ref('')
const isUpdatingNickname = ref(false)
const nicknameError = ref('')

// 获取当前用户信息
const currentUser = computed(() => store.getters.currentUser)
const versionState = computed(() => store.getters.appVersion)
const currentVersionInfo = computed(() => versionState.value.current)
const latestVersion = computed(() => store.getters.latestVersionInfo)
const hasUpdate = computed(() => store.getters.hasAppUpdate)
const checkingUpdate = computed(() => store.getters.appUpdateChecking)
const versionError = computed(() => store.getters.appUpdateError)

watch(versionError, (value) => {
  if (value) {
    toast.error(value)
  }
})

// 监听账号切换，重置对话框状态
// Settings 页面不需要保存状态，因为都是即时操作
watch(
  () => store.state.accounts?.currentAccountId,
  (newAccountId, oldAccountId) => {
    if (newAccountId && oldAccountId && newAccountId !== oldAccountId) {
      
      // 重置对话框状态（Settings 页面的操作是即时的，不需要保存）
      showNicknameDialog.value = false
      newNickname.value = ''
      isUpdatingNickname.value = false
      nicknameError.value = ''
      previewImageUrl.value = ''
      downloadInProgress.value = false
      
    }
  }
)

onMounted(async () => {
  try {
    await store.dispatch('checkAppUpdate')
  } catch (error: any) {
  }
})

// 用户显示名称（优先使用nickname字段作为昵称）
const userDisplayName = computed(() => {
  return currentUser.value.nickname || currentUser.value.userName || currentUser.value.username || '用户'
})

// 用户头像本地路径
const userAvatarLocalPath = computed(() => {
  // 如果有预览图，优先显示预览图
  if (previewImageUrl.value) {
    return previewImageUrl.value
  }
  
  // 否则使用本地缓存的头像路径
  const localPath = currentUser.value.avatarLocalPath
  return localPath && localPath.trim() ? localPath : undefined
})

// 处理更换头像
const handleChangeAvatar = () => {
  // 触发文件选择
  const input = document.createElement('input')
  input.type = 'file'
  // 仅允许常见头像格式
  input.accept = 'image/jpeg,image/png,image/webp,image/gif'
  input.onchange = handleFileSelect
  input.click()
}

// 处理文件选择
const handleFileSelect = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]

  if (!file) {
    return
  }


  // ✅ 增强文件类型验证
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']

  // 验证 MIME 类型
  if (!allowedTypes.includes(file.type)) {
    toast.warning('仅支持 JPG、PNG、WebP、GIF 格式的图片')
    return
  }

  // 验证文件扩展名
  const fileName = file.name.toLowerCase()
  const hasValidExtension = allowedExtensions.some(ext => fileName.endsWith(ext))
  if (!hasValidExtension) {
    toast.warning('文件扩展名不合法')
    return
  }

  // 验证文件大小（限制为 10MB）
  const maxSize = 10 * 1024 * 1024
  if (file.size > maxSize) {
    toast.warning('图片大小不能超过 10MB')
    return
  }

  // ✅ 新增：验证图片尺寸和完整性
  try {
    const img = new Image()
    const objectUrl = URL.createObjectURL(file)

    await new Promise<void>((resolve, reject) => {
      img.onload = () => {
        URL.revokeObjectURL(objectUrl)

        // 限制图片尺寸（防止上传超大图片）
        const maxDimension = 4096
        if (img.width > maxDimension || img.height > maxDimension) {
          reject(new Error(`图片尺寸不能超过 ${maxDimension}x${maxDimension}`))
          return
        }

        resolve()
      }

      img.onerror = () => {
        URL.revokeObjectURL(objectUrl)
        reject(new Error('图片文件已损坏或格式不正确'))
      }

      img.src = objectUrl
    })
  } catch (error: any) {
    toast.warning(error.message || '图片文件无效')
    return
  }

  // 创建预览URL并显示预览
  const previewUrl = URL.createObjectURL(file)
  previewImageUrl.value = previewUrl

  try {
    store.dispatch('showGlobalLoading', '正在上传头像...')

    const uploadResult = await FileApi.uploadFile({
      file,
      category: 'avatar',
      isPublic: true,
      description: '用户头像'
    })


    if (uploadResult.code === 200 && uploadResult.data) {


      // ✅ 修复：UserApi.uploadAvatar() 已完成所有必要的更新（包括 store 更新）
      // 无需再次调用 updateUserInfo() 和 UPDATE_USER_INFO
      // 避免覆盖 avatarLocalPath 为 null

      // 等待下一个 tick 确保 store 更新已完成，再清理预览URL
      await nextTick()

      // 延迟清理预览URL，确保 Avatar 组件已加载新图片
      if (previewImageUrl.value) {
        const oldPreviewUrl = previewImageUrl.value
        previewImageUrl.value = '' // 先清空引用，触发 computed 重新计算


        // 延迟释放 Blob URL，给 Avatar 组件足够时间加载新图片
        setTimeout(() => {
          URL.revokeObjectURL(oldPreviewUrl)
        }, 1000)
      }

      toast.success('头像更新成功')
    } else {
      toast.error(uploadResult.message || '头像上传失败')
    }
  } catch (error) {
    toast.error('头像上传过程中发生错误')
  } finally {
    store.dispatch('hideGlobalLoading')
    // 如果上传失败，也要清理预览URL
    if (previewImageUrl.value) {
      URL.revokeObjectURL(previewImageUrl.value)
      previewImageUrl.value = ''
    }
  }
}

// 处理编辑用户名
const handleEditUsername = () => {
  // 打开昵称修改对话框，使用当前昵称作为默认值
  newNickname.value = currentUser.value.nickname || currentUser.value.userName || currentUser.value.username || ''
  nicknameError.value = ''
  showNicknameDialog.value = true
}

// 处理确认修改昵称
const handleConfirmUpdateNickname = async () => {
  const nickname = newNickname.value.trim()
  
  // 验证输入
  if (!nickname) {
    nicknameError.value = '昵称不能为空'
    return
  }
  
  if (nickname.length > 20) {
    nicknameError.value = '昵称不能超过20个字符'
    return
  }
  
  // 检查是否与当前昵称相同
  const currentNickname = currentUser.value.nickname || currentUser.value.userName || currentUser.value.username || ''
  if (nickname === currentNickname) {
    nicknameError.value = '新昵称与当前昵称相同'
    return
  }
  
  // 开始更新
  isUpdatingNickname.value = true
  nicknameError.value = ''
  
  try {
    store.dispatch('showGlobalLoading', '正在更新昵称...')
    
    // 获取当前完整的用户信息，与bear-chat-uniapp保持一致
    const currentUserInfo = store.getters.currentUser
    const updateParams = {
      ...currentUserInfo,
      userName: nickname  // userName 才是真正的用户昵称字段
    }
    
    
    // 调用更新用户信息API
    const updateResult = await UserApi.updateUserInfo(updateParams)
    
    if (updateResult.code === 200) {
      // 更新store中的用户信息
      store.commit('UPDATE_USER_INFO', { 
        nickname: nickname  // 更新nickname字段，这是真正的用户昵称字段
      })
      
      toast.success('昵称修改成功')
      
      // 关闭对话框
      showNicknameDialog.value = false
      newNickname.value = ''
    } else {
      nicknameError.value = updateResult.message || '昵称修改失败'
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误，请稍后重试';
    nicknameError.value = errorMessage
  } finally {
    store.dispatch('hideGlobalLoading')
    isUpdatingNickname.value = false
  }
}

// 处理取消修改昵称
const handleCancelUpdateNickname = () => {
  showNicknameDialog.value = false
  newNickname.value = ''
  nicknameError.value = ''
  isUpdatingNickname.value = false
}

// 处理查看通用设置
const handleViewGeneral = async () => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/general',
        name: 'GeneralSettings',
        params: {},
        query: {}
      }
    })
  } else {
    // 否则使用全局路由
    try {
      await router.push('/home/general')
    } catch (error: any) {
      console.error('跳转失败:', error)
      toast.error('暂时无法打开通用设置，请稍后重试')
    }
  }
}


// 处理退出登录
const handleLogout = async () => {
  try {
    await store.dispatch('logout')
    // 不需要手动跳转，App.vue 中的 watch token 会自动处理跳转
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '退出登录失败，请稍后再试';
    toast.error(errorMessage)
  }
}

const handleCheckUpdate = async () => {
  try {
    await store.dispatch('checkAppUpdate')
    if (hasUpdate.value) {
      toast.success('检测到新版本，快去更新吧')
    } else {
      toast.success('当前已是最新版本')
    }
  } catch (error: any) {
    toast.error(error?.message || '检查更新失败')
  }
}

const handleDownloadUpdate = async () => {
  if (downloadInProgress.value) {
    return
  }
  downloadInProgress.value = true
  try {
    await store.dispatch('downloadLatestVersion')
    toast.success('已开始下载安装包，请关注更新弹窗进度')
  } catch (error: any) {
    toast.error(error?.message || '下载更新失败')
  } finally {
    downloadInProgress.value = false
  }
}
</script>

<style lang="scss" scoped>

.settings {
  width: 100%;
  height: 100%;
  background-color: $bg-chat;
}

.settings-wrapper {
  min-height: 100%;
  padding: 32px 0 48px;
  display: flex;
  justify-content: center;
  align-items: center;
  flex-direction: column;
  box-sizing: border-box;
  pointer-events: auto;
}

.settings-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
  width: 100%;
  max-width: 360px;
  align-items: center;
  pointer-events: auto;
}

.username-section {
  margin-top: 24px;
}

.phone-section {
  margin-top: 16px;
}

.version-section {
  margin-top: 16px;
  width: 100%;
  display: flex;
  justify-content: center;
  padding: 0 24px;
  box-sizing: border-box;
}

.version-container {
  width: 100%;
  max-width: 360px;
  background-color: #fff;
  border-radius: 16px;
  padding: 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.version-info {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.version-title {
  font-size: 16px;
  font-weight: 600;
  color: #1f2937;
}

.version-detail {
  font-size: 14px;
  color: #4b5563;
}

.version-tag {
  margin-left: 12px;
  padding: 2px 8px;
  background: #2563eb;
  color: #fff;
  border-radius: 999px;
  font-size: 12px;
}

.version-notes {
  font-size: 13px;
  color: #6b7280;
  line-height: 1.4;
}

.version-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  justify-content: center;
}

.version-btn {
  padding: 8px 16px;
  border-radius: 8px;
  border: 1px solid #d1d5db;
  background: #fff;
  color: #374151;
  transition: all 0.2s ease;
}

.version-btn.primary {
  background: #2563eb;
  color: #fff;
  border-color: #2563eb;
}

.version-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.version-btn:not(:disabled):hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(37, 99, 235, 0.1);
}

.general-section {
  margin-top: 24px;
}


.about-section {
  margin-top: 24px;
}

.logout-section {
  margin-top: 24px;
}

.avatar-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.avatar-wrapper {
  position: relative;
  display: inline-block;
}

.avatar-edit-icon {
  position: absolute;
  top: -5px;
  right: -5px;
  width: 36px;
  height: 36px;
  z-index: 1;
  pointer-events: none; /* 禁用编辑图标的独立点击，让父容器处理点击 */
}

.username-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.username-display {
  font-size: 22px;
  font-weight: bold;
  color: #2C2D3A;
}

.username-edit-icon {
  width: 16px;
  height: 16px;
}

.phone-display {
  text-align: center;
}

.phone-label {
  font-size: 14px;
  color: $settings-label-color;
}

.phone-value {
  font-size: 14px;
  color: $settings-text-color;
}

.privacy-container {
  width: 343px;
  height: 78px;
  background-color: white;
  padding: 0 16px;
  border-radius: 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-sizing: border-box;
  pointer-events: auto;
}

.privacy-text {
  font-size: 14px;
  color: #2C2D3A;
}

.privacy-icon {
  width: 24px;
  height: 24px;
}


.logout-btn {
  width: 343px;
  height: 44px;
  background-color: $logout-bg;
  border: none;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  pointer-events: auto;
}

.logout-icon {
  width: 24px;
  height: 24px;
}

.logout-text {
  font-size: 14px;
  color: $logout-text;
}

// 关于 Chatly 弹窗内容
.about-dialog-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
  font-size: 14px;
  color: #2C2D3A;
  line-height: 20px;

  p {
    margin: 0;
  }
}

// 昵称修改对话框样式（参照Contact.vue的添加联系人对话框）
.edit-nickname-content {
  padding: 16px 8px; // 增加左右内边距，减少视觉拥挤感
  
  // 针对 DialogInput 的特殊样式调整
  :deep(.dialog-input) {
    width: 100%; // 恢复全宽
    border-radius: 22px; // 保持与 DialogInput 组件一致的圆角
    padding: 0 20px; // 增加内边距，让文字不会太靠近边缘
    font-size: 14px; // 稍微增大字体
    
    &::placeholder {
      font-size: 14px;
    }
  }
  
  // 错误提示样式
  .nickname-error {
    margin-top: 12px;
    padding: 8px 12px;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    color: #dc2626;
    font-size: 14px;
  }

}
</style>
