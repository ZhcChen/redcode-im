<template>
  <div class="settings">
    <!-- 头像模块 -->
    <div class="settings-section avatar-section">
      <div class="avatar-container">
        <div class="avatar-wrapper" @click="handleChangeAvatar">
          <Avatar 
            :src="userAvatarSrc" 
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

    <!-- 隐私政策模块 -->
    <div class="settings-section privacy-section">
      <div class="privacy-container" @click="handleViewPrivacy">
        <div class="privacy-text">隐私政策</div>
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
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
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

const router = useRouter()
const store = useStore()

// 图片预览状态
const previewImageUrl = ref<string>('')
const downloadInProgress = ref(false)

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

onMounted(async () => {
  try {
    await store.dispatch('checkAppUpdate')
  } catch (error: any) {
    console.warn('初始化版本检查失败:', error)
  }
})

// 用户显示名称（使用userName字段作为昵称）
const userDisplayName = computed(() => {
  return currentUser.value.userName || currentUser.value.username || '用户'
})

// 用户头像地址（如果有预览图则显示预览图，否则使用用户头像或默认头像）
const userAvatarSrc = computed(() => {
  if (previewImageUrl.value) {
    return previewImageUrl.value
  }

  if (currentUser.value.avatarLocalPath && currentUser.value.avatarLocalPath.trim()) {
    return currentUser.value.avatarLocalPath
  }

  const firstChar = userDisplayName.value.charAt(0).toUpperCase()
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(firstChar)}&background=6366f1&color=ffffff&size=96&rounded=true`
})

// 监听 avatarLocalPath 变化
watch(
  () => currentUser.value.avatarLocalPath,
  (newPath, oldPath) => {
    console.log('[Settings] 👀 avatarLocalPath 变化:', { oldPath, newPath })
    console.log('[Settings] 👀 userAvatarSrc 重新计算:', userAvatarSrc.value)
  },
  { immediate: true }
)

// 监听 userAvatarSrc 变化
watch(
  userAvatarSrc,
  (newSrc, oldSrc) => {
    console.log('[Settings] 👀 userAvatarSrc 变化:', { oldSrc, newSrc })
  }
)

// 处理更换头像
const handleChangeAvatar = () => {
  console.log('[Settings] 🖼️ 用户点击更换头像', {
    userId: currentUser.value?.id,
    username: currentUser.value?.userName || currentUser.value?.username
  })
  // 触发文件选择
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*'
  input.onchange = handleFileSelect
  input.click()
}

// 处理文件选择
const handleFileSelect = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]

  if (!file) {
    console.warn('[Settings] ⚠️ 文件选择对话框被关闭，未获取到文件')
    return
  }

  console.log('[Settings] 📥 捕获到待上传头像', {
    name: file.name,
    type: file.type,
    size: file.size
  })

  // ✅ 增强文件类型验证
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']

  // 验证 MIME 类型
  if (!allowedTypes.includes(file.type)) {
    console.warn('[Settings] ⚠️ 不支持的 MIME 类型被拦截', { type: file.type })
    toast.warning('仅支持 JPG、PNG、WebP、GIF 格式的图片')
    return
  }

  // 验证文件扩展名
  const fileName = file.name.toLowerCase()
  const hasValidExtension = allowedExtensions.some(ext => fileName.endsWith(ext))
  if (!hasValidExtension) {
    console.warn('[Settings] ⚠️ 非法文件扩展名被拦截', { fileName })
    toast.warning('文件扩展名不合法')
    return
  }

  // 验证文件大小（限制为 10MB）
  const maxSize = 10 * 1024 * 1024
  if (file.size > maxSize) {
    console.warn('[Settings] ⚠️ 图片超过大小限制', { size: file.size, maxSize })
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
    console.warn('[Settings] ⚠️ 图片验证失败', error)
    toast.warning(error.message || '图片文件无效')
    return
  }

  // 创建预览URL并显示预览
  const previewUrl = URL.createObjectURL(file)
  previewImageUrl.value = previewUrl
  console.log('[Settings] 🖥️ 生成头像预览 URL', previewUrl)

  try {
    console.log('[Settings] 🚀 准备调度头像上传流程')
    store.dispatch('showGlobalLoading', '正在上传头像...')

    console.log('[Settings] 📤 调用 FileApi.uploadFile 提交头像...')
    const uploadResult = await FileApi.uploadFile({
      file,
      category: 'avatar',
      isPublic: true,
      description: '用户头像'
    })

    console.log('[Settings] 📦 FileApi 返回结果', uploadResult)

    if (uploadResult.code === 200 && uploadResult.data) {
      console.log('[Settings] ✅ 头像上传成功，服务器响应', uploadResult.data)

      console.log('[Settings] 📊 检查返回的数据:', {
        avatarUrl: uploadResult.data.fileUrl,
        objectKey: uploadResult.data.objectKey,
        localPath: uploadResult.data.localPath
      })

      // ✅ 修复：UserApi.uploadAvatar() 已完成所有必要的更新（包括 store 更新）
      // 无需再次调用 updateUserInfo() 和 UPDATE_USER_INFO
      // 避免覆盖 avatarLocalPath 为 null

      // 等待下一个 tick 确保 store 更新已完成，再清理预览URL
      await nextTick()
      console.log('[Settings] 📊 nextTick 后检查 currentUser 状态:', {
        avatar: currentUser.value.avatar,
        avatarObjectKey: currentUser.value.avatarObjectKey,
        avatarLocalPath: currentUser.value.avatarLocalPath
      })

      // 延迟清理预览URL，确保 Avatar 组件已加载新图片
      if (previewImageUrl.value) {
        const oldPreviewUrl = previewImageUrl.value
        previewImageUrl.value = '' // 先清空引用，触发 computed 重新计算

        console.log('[Settings] 📊 清理预览后 userAvatarSrc 计算值:', userAvatarSrc.value)

        // 延迟释放 Blob URL，给 Avatar 组件足够时间加载新图片
        setTimeout(() => {
          URL.revokeObjectURL(oldPreviewUrl)
          console.log('[Settings] ♻️ 已释放预览 Blob URL')
        }, 1000)
      }

      toast.success('头像更新成功')
    } else {
      toast.error(uploadResult.message || '头像上传失败')
      console.error('[Settings] ❌ 头像上传失败', {
        message: uploadResult.message,
        code: uploadResult.code
      })
    }
  } catch (error) {
    toast.error('头像上传过程中发生错误')
    console.error('[Settings] ❌ 头像上传过程中发生异常', error)
  } finally {
    console.log('[Settings] 🧹 结束头像上传流程，隐藏全局 Loading')
    store.dispatch('hideGlobalLoading')
    // 如果上传失败，也要清理预览URL
    if (previewImageUrl.value) {
      console.log('[Settings] ♻️ 清理未提交的头像预览资源')
      URL.revokeObjectURL(previewImageUrl.value)
      previewImageUrl.value = ''
    }
  }
}

// 处理编辑用户名
const handleEditUsername = () => {
  console.log('编辑用户名')
  // 打开昵称修改对话框
  newNickname.value = currentUser.value.userName || currentUser.value.username || ''
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
  const currentNickname = currentUser.value.userName || currentUser.value.username || ''
  if (nickname === currentNickname) {
    nicknameError.value = '新昵称与当前昵称相同'
    return
  }
  
  // 开始更新
  isUpdatingNickname.value = true
  nicknameError.value = ''
  
  try {
    console.log('开始更新昵称:', nickname)
    store.dispatch('showGlobalLoading', '正在更新昵称...')
    
    // 获取当前完整的用户信息，与bear-chat-uniapp保持一致
    const currentUserInfo = store.getters.currentUser
    const updateParams = {
      ...currentUserInfo,
      userName: nickname  // userName 才是真正的用户昵称字段
    }
    
    console.log('更新参数:', updateParams)
    
    // 调用更新用户信息API
    const updateResult = await UserApi.updateUserInfo(updateParams)
    
    if (updateResult.code === 200) {
      // 更新store中的用户信息
      store.commit('UPDATE_USER_INFO', { 
        userName: nickname  // 更新userName字段，这是真正的用户昵称字段
      })
      
      console.log('昵称更新成功')
      toast.success('昵称修改成功')
      
      // 关闭对话框
      showNicknameDialog.value = false
      newNickname.value = ''
    } else {
      nicknameError.value = updateResult.message || '昵称修改失败'
      console.error('昵称更新失败:', updateResult.message)
    }
  } catch (error: any) {
    console.error('昵称修改过程中发生错误:', error)
    nicknameError.value = error.message || '网络错误，请稍后重试'
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

// 处理查看隐私政策
const handleViewPrivacy = async () => {
  console.log('查看隐私政策')
  try {
    await router.push('/home/privacy')
  } catch (error) {
    console.error('跳转隐私政策失败:', error)
    toast.error('暂时无法打开隐私政策，请稍后重试')
  }
}

// 处理退出登录
const handleLogout = async () => {
  console.log('🔄 用户点击退出登录...')
  try {
    await store.dispatch('logout')
    // 不需要手动跳转，App.vue 中的 watch token 会自动处理跳转
  } catch (error: any) {
    console.error('退出登录失败:', error)
    toast.error(error?.message || '退出登录失败，请稍后再试')
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
  padding: 32px 0 48px;
  display: flex;
  justify-content: flex-start;
  align-items: center;
  background-color: $bg-chat;
  flex-direction: column;
  overflow-y: auto;
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
  cursor: pointer;
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

.privacy-section {
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
  cursor: pointer;
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
  cursor: pointer;
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
  cursor: pointer;
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
  cursor: pointer;
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
