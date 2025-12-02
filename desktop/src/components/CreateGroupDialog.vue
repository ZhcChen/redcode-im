<template>
  <Mask :visible="visible" @update:visible="handleVisibleChange" @close="handleClose">
    <div class="create-group-dialog">
      <!-- 头部 -->
      <div class="dialog-header">
        <div class="title">创建群聊</div>
        <div class="close-btn" @click="handleClose">×</div>
      </div>

      <!-- 内容区域 -->
      <ScrollContainer class="dialog-content">
        <!-- 群头像 -->
        <div class="avatar-section">
          <div class="avatar-wrapper" @click="handleAvatarClick">
            <img v-if="groupAvatar" :src="groupAvatar" class="avatar-image" alt="群头像" />
            <div v-else class="avatar-placeholder">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="#999"/>
              </svg>
            </div>
          </div>
          <div class="avatar-hint">点击上传群头像（选填）</div>
        </div>

        <!-- 群名称 -->
        <div class="form-group">
          <label class="form-label">群聊名称</label>
          <BInput
            v-model="groupName"
            placeholder="请输入群聊名称"
            :maxlength="20"
            :disabled="isCreating"
          />
          <div v-if="errors.groupName" class="error-text">{{ errors.groupName }}</div>
        </div>

        <!-- 群公告 -->
        <div class="form-group">
          <label class="form-label">群公告（选填）</label>
          <textarea
            v-model="groupNotice"
            class="notice-textarea"
            placeholder="请输入群公告"
            maxlength="200"
            rows="3"
            :disabled="isCreating"
          ></textarea>
          <div class="notice-count">{{ groupNotice.length }}/200</div>
        </div>

        <!-- 群成员 -->
        <div class="form-group">
          <div class="member-header">
            <label class="form-label">群成员（{{ selectedMemberIds.length }}）</label>
            <button class="add-member-btn" @click="handleSelectMembers" :disabled="isLoadingContacts">
              {{ isLoadingContacts ? '加载中...' : '添加好友' }}
            </button>
          </div>

          <div v-if="isLoadingContacts" class="loading-state">
            <div class="loading-spinner"></div>
            <div class="loading-text">加载好友列表中...</div>
          </div>
          <div v-else-if="selectedMembers.length === 0" class="empty-state">
            点击右侧按钮，选择至少一位好友加入群聊
          </div>
          <ScrollContainer v-else class="selected-members" size="thin">
            <div
            v-for="member in selectedMembers"
            :key="member.id"
            class="member-chip"
          >
              <Avatar :src="member.avatar" :text="member.nickname" :color-seed="member.id" :size="32" />
              <span class="member-name">{{ member.nickname }}</span>
              <div class="remove-btn" @click="removeMember(member.id)">×</div>
            </div>
          </ScrollContainer>
          <div v-if="errors.members" class="error-text">{{ errors.members }}</div>
        </div>
      </ScrollContainer>

      <!-- 底部操作按钮 -->
      <div class="dialog-footer">
        <button class="cancel-btn" @click="handleClose" :disabled="isCreating">取消</button>
        <button class="confirm-btn" @click="handleCreate" :disabled="isCreating || !canCreate">
          {{ isCreating ? '创建中...' : '创建群聊' }}
        </button>
      </div>

      <!-- 隐藏的文件输入 -->
  <input
    ref="avatarInputRef"
    type="file"
    accept="image/jpeg,image/png,image/webp,image/gif"
    style="display: none"
    @change="handleAvatarChange"
  />
    </div>
  </Mask>

  <!-- 成员选择对话框 -->
  <AddGroupMemberDialog
    v-model:visible="showMemberSelector"
    :contacts="contacts"
    :selected-ids="selectedMemberIds"
    @confirm="handleMembersSelected"
    @close="showMemberSelector = false"
  />
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import Mask from './Mask.vue'
import BInput from './BInput.vue'
import Avatar from './Avatar.vue'
import AddGroupMemberDialog from './AddGroupMemberDialog.vue'
import ScrollContainer from './ScrollContainer.vue'

interface Contact {
  id: string
  nickname: string
  avatar: string
  username?: string
}

interface Props {
  visible: boolean
  contacts: Contact[]
  isLoadingContacts?: boolean
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
  (e: 'create', data: {
    name: string
    notice?: string
    avatar?: string
    memberIds: string[]
  }): void
  (e: 'load-contacts'): void
}

const props = withDefaults(defineProps<Props>(), {
  isLoadingContacts: false
})

const emit = defineEmits<Emits>()

// 表单数据
const groupName = ref('')
const groupNotice = ref('')
const groupAvatar = ref<string>()
const avatarFile = ref<File>()
const selectedMemberIds = ref<string[]>([])

// 状态
const isCreating = ref(false)
const showMemberSelector = ref(false)
const avatarInputRef = ref<HTMLInputElement>()

// 错误信息
const errors = ref({
  groupName: '',
  members: ''
})

// 已选成员详情
const selectedMembers = computed(() => {
  return props.contacts.filter(contact => selectedMemberIds.value.includes(contact.id))
})

// 是否可以创建
const canCreate = computed(() => {
  return groupName.value.trim() !== '' && selectedMemberIds.value.length > 0
})

// 处理头像点击
const handleAvatarClick = () => {
  if (isCreating.value) return
  avatarInputRef.value?.click()
}

// 处理头像文件变化
const handleAvatarChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  
  if (file) {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']

    if (!allowedTypes.includes(file.type)) {
      errors.value.groupName = '仅支持 JPG、PNG、WebP、GIF 图片'
      return
    }

    const fileName = file.name.toLowerCase()
    const hasValidExtension = allowedExtensions.some(ext => fileName.endsWith(ext))
    if (!hasValidExtension) {
      errors.value.groupName = '文件扩展名不合法'
      return
    }
    
    if (file.size > 5 * 1024 * 1024) {
      errors.value.groupName = '图片大小不能超过 5MB'
      return
    }
    
    avatarFile.value = file
    
    // 预览
    const reader = new FileReader()
    reader.onload = (e) => {
      groupAvatar.value = e.target?.result as string
    }
    reader.readAsDataURL(file)
  }
  
  // 重置 input
  target.value = ''
}

// 处理选择成员
const handleSelectMembers = () => {
  if (props.contacts.length === 0 && !props.isLoadingContacts) {
    emit('load-contacts')
  }
  showMemberSelector.value = true
}

// 处理成员选择完成
const handleMembersSelected = (memberIds: string[]) => {
  selectedMemberIds.value = memberIds
  errors.value.members = ''
}

// 移除成员
const removeMember = (memberId: string) => {
  const index = selectedMemberIds.value.indexOf(memberId)
  if (index > -1) {
    selectedMemberIds.value.splice(index, 1)
  }
}

// 验证表单
const validateForm = (): boolean => {
  errors.value = {
    groupName: '',
    members: ''
  }
  
  let isValid = true
  
  if (!groupName.value.trim()) {
    errors.value.groupName = '请输入群聊名称'
    isValid = false
  } else if (groupName.value.length > 20) {
    errors.value.groupName = '群名不能超过20个字符'
    isValid = false
  }
  
  if (selectedMemberIds.value.length === 0) {
    errors.value.members = '请至少选择一位好友加入群聊'
    isValid = false
  }
  
  return isValid
}

// 处理创建
const handleCreate = () => {
  if (!validateForm()) return
  
  emit('create', {
    name: groupName.value.trim(),
    notice: groupNotice.value.trim() || undefined,
    avatar: groupAvatar.value,
    memberIds: selectedMemberIds.value
  })
}

// 重置表单
const resetForm = () => {
  groupName.value = ''
  groupNotice.value = ''
  groupAvatar.value = undefined
  avatarFile.value = undefined
  selectedMemberIds.value = []
  errors.value = {
    groupName: '',
    members: ''
  }
}

// 处理visible变化
const handleVisibleChange = (newVisible: boolean) => {
  emit('update:visible', newVisible)
}

// 关闭对话框
const handleClose = () => {
  if (isCreating.value) return
  resetForm()
  emit('update:visible', false)
  emit('close')
}

// 监听visible变化
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    resetForm()
    // 如果没有联系人数据且未在加载，触发加载
    if (props.contacts.length === 0 && !props.isLoadingContacts) {
      emit('load-contacts')
    }
  } else {
    showMemberSelector.value = false
  }
})

// 暴露创建状态控制方法
defineExpose({
  setCreating: (value: boolean) => {
    isCreating.value = value
  }
})
</script>

<style lang="scss" scoped>
.create-group-dialog {
  width: 560px;
  background: white;
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
  box-sizing: border-box;

  * {
    box-sizing: border-box;
  }
}

.dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;

  .title {
    font-size: 18px;
    font-weight: 600;
    color: #333;
  }

  .close-btn {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 28px;
    color: #999;
    border-radius: 6px;
    transition: all 0.2s;

    &:hover {
      background: #f5f5f5;
      color: #666;
    }
  }
}

.dialog-content {
  flex: 1;
  padding: 24px;
  min-height: 0;

  .avatar-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-bottom: 32px;

    .avatar-wrapper {
      width: 100px;
      height: 100px;
      border-radius: 20px;
      overflow: hidden;
      transition: all 0.2s;

      &:hover {
        transform: scale(1.05);
      }

      .avatar-image {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }

      .avatar-placeholder {
        width: 100%;
        height: 100%;
        background: #f5f5f5;
        display: flex;
        align-items: center;
        justify-content: center;
      }
    }

    .avatar-hint {
      margin-top: 12px;
      font-size: 12px;
      color: #999;
    }
  }

  .form-group {
    margin-bottom: 24px;

    &:last-child {
      margin-bottom: 0;
    }

    .form-label {
      display: block;
      font-size: 14px;
      font-weight: 500;
      color: #333;
      margin-bottom: 8px;
    }

    .notice-textarea {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      font-size: 14px;
      font-family: inherit;
      resize: none;
      transition: border-color 0.2s;

      &:focus {
        outline: none;
        border-color: var(--primary-color, #007bff);
      }

      &:disabled {
        background: #f5f5f5;
        cursor: not-allowed;
      }
    }

    .notice-count {
      margin-top: 4px;
      font-size: 12px;
      color: #999;
      text-align: right;
    }

    .member-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;

      .add-member-btn {
        padding: 6px 16px;
        background: transparent;
        border: 1px solid var(--primary-color, #007bff);
        color: var(--primary-color, #007bff);
        border-radius: 6px;
        font-size: 14px;
        transition: all 0.2s;

        &:hover:not(:disabled) {
          background: var(--primary-color, #007bff);
          color: white;
        }

        &:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }
      }
    }

    .loading-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 32px;
      color: #999;

      .loading-spinner {
        width: 32px;
        height: 32px;
        border: 3px solid #f0f0f0;
        border-top-color: var(--primary-color, #007bff);
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
      }

      .loading-text {
        margin-top: 12px;
        font-size: 14px;
      }
    }

    .empty-state {
      padding: 32px;
      text-align: center;
      color: #999;
      font-size: 14px;
      background: #f8f9fa;
      border-radius: 8px;
    }

    .selected-members {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      padding: 16px;
      background: #f8f9fa;
      border-radius: 8px;
      max-height: 200px;

      .member-chip {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 12px 6px 6px;
        background: white;
        border-radius: 20px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        position: relative;
        transition: all 0.2s;

        &:hover {
          box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);

          .remove-btn {
            opacity: 1;
          }
        }

        .member-name {
          font-size: 14px;
          color: #333;
          max-width: 100px;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .remove-btn {
          width: 20px;
          height: 20px;
          background: #ff4757;
          color: white;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 16px;
          font-weight: bold;
          opacity: 0;
          transition: opacity 0.2s;
        }
      }
    }

    .error-text {
      margin-top: 6px;
      font-size: 12px;
      color: #ff4757;
    }
  }
}

.dialog-footer {
  padding: 16px 24px;
  border-top: 1px solid #f0f0f0;
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  flex-shrink: 0;

  .cancel-btn,
  .confirm-btn {
    padding: 10px 24px;
    border-radius: 8px;
    font-size: 14px;
    transition: all 0.2s;
    border: none;

    &:disabled {
      cursor: not-allowed;
      opacity: 0.5;
    }
  }

  .cancel-btn {
    background: #f8f9fa;
    color: #666;

    &:hover:not(:disabled) {
      background: #e9ecef;
    }
  }

  .confirm-btn {
    background: var(--primary-color, #007bff);
    color: white;

    &:hover:not(:disabled) {
      opacity: 0.9;
    }
  }
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
