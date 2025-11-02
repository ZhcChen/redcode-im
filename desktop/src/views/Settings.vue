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
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
import Avatar from '../components/Avatar.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import { FileApi } from '../api/file'
import { UserApi } from '../api/user'
import { fileConfig } from '../api/config'
import { toast } from '../utils/toast'
import rightIcon from '../assets/image/icon/right.svg'
import logoutIcon from '../assets/image/icon-logout-red.svg'
import editIcon from '../assets/image/icon-edit.svg'
import penIcon from '../assets/image/icon-pen.svg'

const router = useRouter()
const store = useStore()

// 图片预览状态
const previewImageUrl = ref<string>('')

// 昵称修改相关状态
const showNicknameDialog = ref(false)
const newNickname = ref('')
const isUpdatingNickname = ref(false)
const nicknameError = ref('')

// 获取当前用户信息
const currentUser = computed(() => store.getters.currentUser)

// 用户显示名称（使用userName字段作为昵称）
const userDisplayName = computed(() => {
  return currentUser.value.userName || currentUser.value.username || '用户'
})

// 用户头像地址（如果有预览图则显示预览图，否则使用用户头像或默认头像）
const userAvatarSrc = computed(() => {
  // 如果有预览图，优先显示预览图
  if (previewImageUrl.value) {
    return previewImageUrl.value
  }
  
  if (currentUser.value.avatar && currentUser.value.avatar.trim()) {
    return currentUser.value.avatar
  }
  // 使用用户名的首字符生成默认头像
  const firstChar = userDisplayName.value.charAt(0).toUpperCase()
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(firstChar)}&background=6366f1&color=ffffff&size=96&rounded=true`
})

// 处理更换头像
const handleChangeAvatar = () => {
  console.log('更换头像')
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
    return
  }

  // 验证文件类型
  if (!file.type.startsWith('image/')) {
    toast.warning('请选择图片文件')
    return
  }

  // 验证文件大小（限制为5MB）
  const maxSize = 5 * 1024 * 1024
  if (file.size > maxSize) {
    toast.warning('图片大小不能超过5MB')
    return
  }

  // 创建预览URL并显示预览
  const previewUrl = URL.createObjectURL(file)
  previewImageUrl.value = previewUrl

  try {
    console.log('开始上传头像...')
    store.dispatch('showGlobalLoading', '正在上传头像...')

    // 调用文件上传API
    const uploadResult = await FileApi.uploadFile({
      file,
      category: 'avatar',
      isPublic: true,
      description: '用户头像'
    })

    if (uploadResult.code === 200 && uploadResult.data) {
      // 根据bear-chat-uniapp的逻辑构造头像URL
      const fileInfo = uploadResult.data
      console.log('头像上传响应结果:', fileInfo)
      
      // 使用统一的图片URL构建函数
      const avatarUrl = FileApi.buildImageUrl(fileInfo)
      console.log('构造的头像URL:', avatarUrl)

      // 获取当前完整的用户信息，与bear-chat-uniapp保持一致
      const currentUserInfo = store.getters.currentUser
      const updateParams = {
        ...currentUserInfo,
        avatar: avatarUrl
      }

      // 更新用户头像
      const updateResult = await UserApi.updateUserInfo(updateParams)

      if (updateResult.code === 200) {
        // 更新store中的用户信息
        store.commit('UPDATE_USER_INFO', { avatar: avatarUrl })
        console.log('头像更新成功')
        // 清理预览URL
        if (previewImageUrl.value) {
          URL.revokeObjectURL(previewImageUrl.value)
          previewImageUrl.value = ''
        }
      } else {
        toast.error(updateResult.message || '头像更新失败')
        console.error('头像更新失败:', updateResult.message)
      }
    } else {
      toast.error(uploadResult.message || '头像上传失败')
      console.error('头像上传失败:', uploadResult.message)
    }
  } catch (error) {
    toast.error('头像上传过程中发生错误')
    console.error('头像上传过程中发生错误:', error)
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
const handleViewPrivacy = () => {
  console.log('查看隐私政策')
  // 导航到隐私协议页面
  router.push('/home/privacy')
}

// 处理退出登录
const handleLogout = () => {
  console.log('🔄 用户点击退出登录...')

  // 调用 store 的 logout action
  store.dispatch('logout')
  console.log('✅ 退出登录请求已发送')

  // 添加fallback机制，5秒后强制清除状态（防止死循环）
  setTimeout(() => {
    const currentToken = store.state.token
    const loadingVisible = store.getters.globalLoading.visible

    if (currentToken || loadingVisible) {
      console.warn('⚠️ 检测到退出登录可能卡住，执行强制清除')

      // 强制隐藏加载蒙版
      if (loadingVisible) {
        store.dispatch('hideGlobalLoading')
      }

      // 强制清除token
      if (currentToken) {
        store.commit('SET_TOKEN', null)
        store.commit('LOGOUT_USER')

        // 重置窗口标题
        try {
          import('@/utils').then(({ updateWindowTitle }) => {
            updateWindowTitle() // 不传参数，显示默认标题
          }).catch(error => {
            console.warn('重置窗口标题失败:', error)
          })
        } catch (error) {
          console.warn('无法加载utils模块:', error)
        }
      }

      // 强制跳转到登录页
      router.push('/login')
    }
  }, 5000) // 5秒后检查
}
</script>

<style lang="scss" scoped>
.settings {
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: $bg-chat;
  flex-direction: column;
}

.settings-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.username-section {
  margin-top: 24px;
}

.phone-section {
  margin-top: 16px;
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
