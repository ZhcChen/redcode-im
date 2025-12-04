<template>
  <Dialog
    v-model="internalVisible"
    title="创建群聊"
    :width="'680px'"
    :confirm-text="isCreating ? '创建中...' : '创建群聊'"
    :confirm-disabled="isCreating || !canCreate"
    @confirm="handleCreate"
    @cancel="handleClose"
    @close="handleClose"
  >
    <div class="create-group-dialog">
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
          <DialogInput
            v-model="groupName"
            placeholder="请输入群聊名称"
            :maxlength="20"
            :disabled="isCreating"
          />
          <div v-if="errors.groupName" class="error-text">{{ errors.groupName }}</div>
        </div>

        <!-- 群成员 -->
        <div class="form-group">
          <div class="member-header-inline">
            <label class="form-label">群成员（{{ selectedMemberIds.length }}）</label>
            <span class="member-hint">选择至少一位好友加入群聊</span>
          </div>

          <div class="member-picker" :class="{ loading: isLoadingContacts }">
            <div class="picker-left">
              <div class="search-wrapper">
                <SearchInput
                  v-model="searchKeyword"
                  placeholder="搜索联系人..."
                />
              </div>

              <ScrollContainer class="contact-list" size="thin">
                <div v-if="isLoadingContacts" class="loading-state inline">
                  <div class="loading-spinner"></div>
                  <div class="loading-text">加载好友列表中...</div>
                </div>
                <div v-else-if="filteredContacts.length === 0" class="empty-state inline">
                  <div class="empty-text">{{ searchKeyword ? '未找到匹配的联系人' : '暂无可添加的联系人' }}</div>
                </div>
                <div
                  v-else
                  v-for="contact in filteredContacts"
                  :key="contact.id"
                  class="contact-item"
                  :class="{ selected: isSelected(contact.id) }"
                  @click="toggleContact(contact)"
                >
                  <div class="contact-info">
                    <Avatar :src="contact.avatar" :text="contact.nickname" :color-seed="contact.id" :size="36" />
                    <div class="name">{{ contact.nickname }}</div>
                  </div>
                  <div class="select-indicator">{{ isSelected(contact.id) ? '✓' : '' }}</div>
                </div>
              </ScrollContainer>
            </div>

            <div class="picker-right">
              <div class="selected-header">
                <div class="title">已选择 {{ selectedMembers.length }} 人</div>
                <div class="subtitle">点击可移除</div>
              </div>
              <ScrollContainer class="selected-members" size="thin">
                <div v-if="selectedMembers.length === 0" class="empty-state inline">
                  <div class="empty-text">尚未选择成员</div>
                </div>
                <div
                  v-else
                  v-for="member in selectedMembers"
                  :key="member.id"
                  class="member-chip"
                  @click="removeMember(member.id)"
                >
                  <Avatar :src="member.avatar" :text="member.nickname" :color-seed="member.id" :size="28" />
                  <span class="member-name">{{ member.nickname }}</span>
                  <div class="remove-btn">×</div>
                </div>
              </ScrollContainer>
            </div>
          </div>
          <div v-if="errors.members" class="error-text">{{ errors.members }}</div>
        </div>
      </ScrollContainer>

      <!-- 隐藏的文件输入 -->
      <input
        ref="avatarInputRef"
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        style="display: none"
        @change="handleAvatarChange"
      />
    </div>
  </Dialog>

</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import Dialog from './Dialog.vue'
import Avatar from './Avatar.vue'
import ScrollContainer from './ScrollContainer.vue'
import DialogInput from './DialogInput.vue'
import SearchInput from './SearchInput.vue'

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
const groupAvatar = ref<string>()
const avatarFile = ref<File>()
const selectedMemberIds = ref<string[]>([])
const searchKeyword = ref('')

// 状态
const isCreating = ref(false)
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

const filteredContacts = computed(() => {
  if (!searchKeyword.value) return props.contacts
  const keyword = searchKeyword.value.toLowerCase()
  return props.contacts.filter(contact =>
    contact.nickname.toLowerCase().includes(keyword) ||
    (contact.username && contact.username.toLowerCase().includes(keyword))
  )
})

const isSelected = (contactId: string) => selectedMemberIds.value.includes(contactId)

const toggleContact = (contact: Contact) => {
  const index = selectedMemberIds.value.indexOf(contact.id)
  if (index > -1) {
    selectedMemberIds.value.splice(index, 1)
  } else {
    selectedMemberIds.value.push(contact.id)
    errors.value.members = ''
  }
}

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
    avatar: groupAvatar.value,
    memberIds: selectedMemberIds.value
  })

  // 点击确认后立即收起弹窗，避免成功后仍停留
  internalVisible.value = false
  emit('update:visible', false)
}

// 重置表单
const resetForm = () => {
  groupName.value = ''
  groupAvatar.value = undefined
  avatarFile.value = undefined
  selectedMemberIds.value = []
  searchKeyword.value = ''
  errors.value = {
    groupName: '',
    members: ''
  }
}

// 可见性控制（同步 Dialog）
// 可见性控制（同步 Dialog）
const internalVisible = ref(props.visible)

watch(() => props.visible, (newVisible) => {
  internalVisible.value = newVisible
  if (newVisible) {
    resetForm()
    if (props.contacts.length === 0 && !props.isLoadingContacts) {
      emit('load-contacts')
    }
  }
})

watch(internalVisible, (newVisible) => {
  emit('update:visible', newVisible)
})

const handleClose = () => {
  if (isCreating.value) return
  resetForm()
  internalVisible.value = false
  emit('close')
}

// 暴露创建状态控制方法
defineExpose({
  setCreating: (value: boolean) => {
    isCreating.value = value
  }
})
</script>

<style lang="scss" scoped>
.create-group-dialog {
  width: 100%;
  background: transparent;
  border-radius: 0;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
  box-sizing: border-box;
  user-select: none;
  cursor: default;

  * {
    box-sizing: border-box;
    user-select: none;
    cursor: default;
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
  padding: 0;
  min-height: 0;

    .avatar-section {
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 32px;

      .avatar-wrapper {
        width: 72px;
        height: 72px;
        border-radius: 50%;
        overflow: hidden;
        transition: all 0.2s;
        background: #fff;
        border: 1px solid #f0f0f0;

        .avatar-image {
          width: 100%;
          height: 100%;
          object-fit: cover;
        }

        .avatar-placeholder {
          width: 100%;
          height: 100%;
          background: #ffffff;
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
      background: #ffffff;
      border: none;
      border-radius: 8px;
    }

    .selected-members {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      padding: 16px;
      background: #ffffff;
      border-radius: 8px;
      border: none;
      max-height: 200px;

      .member-chip {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 8px 6px 10px;
        margin: 6px 0;
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
          margin-left: auto;
          width: 18px;
          height: 18px;
          background: #ff4d4f;
          color: #fff;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 12px;
          opacity: 0.8;
          transition: opacity 0.2s;
          cursor: pointer;

          &:hover {
            opacity: 1;
          }
        }
      }
    }

    .error-text {
      margin-top: 6px;
      font-size: 12px;
      color: #ff4757;
    }
  }

  .member-header-inline {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 12px;

    .member-hint {
      font-size: 12px;
      color: #999;
    }
  }

  .member-picker {
    display: grid;
    grid-template-columns: 1.3fr 1fr;
    gap: 12px;
    align-items: stretch;

    .picker-left,
    .picker-right {
      background: #fff;
      border-radius: 10px;
      display: flex;
      flex-direction: column;
      min-height: 260px;
      box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    }

    .search-wrapper {
      padding: 12px;
      border-bottom: 1px solid #f3f4f6;
    }

    .contact-list {
      flex: 1;
      padding: 8px 12px 12px;

      .contact-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 8px 10px;
        border-radius: 8px;
        background: #fafbfc;
        border: 1px solid transparent;
        transition: all 0.15s ease;
        margin: 10px 0;
        cursor: pointer;

        &.selected {
          border-color: #00c2b3;
          background: #e8fffa;
        }

        .contact-info {
          display: flex;
          align-items: center;
          gap: 10px;

          .name {
            font-size: 14px;
            color: #333;
            max-width: 140px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }
        }

        .select-indicator {
          width: 18px;
          height: 18px;
          border-radius: 50%;
          border: 1px solid #dcdfe6;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 12px;
          color: #00c2b3;
        }
      }
    }

    .picker-right {
      .selected-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 12px;
        border-bottom: 1px solid #f3f4f6;

        .title {
          font-size: 14px;
          font-weight: 600;
          color: #333;
        }
        .subtitle {
          font-size: 12px;
          color: #999;
        }
      }
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
