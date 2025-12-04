<template>
  <Dialog
    v-model="isVisible"
    title="添加群成员"
    :disable-text-selection="true"
    :confirm-text="confirmText"
    :confirm-disabled="selectedIds.length === 0"
    width="500px"
    @confirm="handleConfirm"
    @cancel="handleCancel"
  >
    <div class="add-member-content">
      <!-- 搜索框 -->
      <SearchInput
        v-model="searchKeyword"
        placeholder="搜索联系人..."
      />

      <!-- 联系人列表 -->
      <ScrollContainer class="contact-list">
        <!-- 空状态提示 -->
        <div v-if="filteredContacts.length === 0" class="empty-state">
          <div class="empty-text">{{ searchKeyword ? '未找到匹配的联系人' : '暂无可添加的联系人' }}</div>
          <div v-if="!searchKeyword && props.contacts.length === 0" class="empty-hint">请先添加好友</div>
        </div>

        <div
          v-for="contact in filteredContacts"
          :key="contact.id"
          class="contact-item"
          @click="toggleContact(contact)"
        >
          <BCheckbox
            :model-value="isSelected(contact.id)"
          />
          <Avatar :src="contact.avatar" :text="contact.nickname" :color-seed="contact.id" :size="40" />
          <div class="contact-name">{{ contact.nickname }}</div>
        </div>
      </ScrollContainer>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import Dialog from './Dialog.vue'
import SearchInput from './SearchInput.vue'
import Avatar from './Avatar.vue'
import ScrollContainer from './ScrollContainer.vue'
import BCheckbox from './BCheckbox.vue'

interface Contact {
  id: string
  nickname: string
  avatar: string
  username?: string
}

interface Props {
  visible: boolean
  contacts: Contact[]
  selectedIds?: string[]
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
  (e: 'confirm', selectedIds: string[]): void
}

const props = withDefaults(defineProps<Props>(), {
  selectedIds: () => []
})

const emit = defineEmits<Emits>()

// 内部可见性状态
const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

// 搜索关键词
const searchKeyword = ref('')

// 选中的联系人ID列表
const selectedIds = ref<string[]>([...props.selectedIds])

// 确认按钮文本
const confirmText = computed(() => {
  if (selectedIds.value.length === 0) {
    return '请选择联系人'
  }
  return `添加 ${selectedIds.value.length} 位联系人`
})

// 过滤后的联系人列表
const filteredContacts = computed(() => {
  if (!searchKeyword.value) return props.contacts

  return props.contacts.filter(contact =>
    contact.nickname.toLowerCase().includes(searchKeyword.value.toLowerCase()) ||
    (contact.username && contact.username.toLowerCase().includes(searchKeyword.value.toLowerCase()))
  )
})

// 判断联系人是否被选中
const isSelected = (contactId: string) => {
  return selectedIds.value.includes(contactId)
}

// 切换联系人选中状态
const toggleContact = (contact: Contact) => {
  const index = selectedIds.value.indexOf(contact.id)
  if (index > -1) {
    selectedIds.value.splice(index, 1)
  } else {
    selectedIds.value.push(contact.id)
  }
}

// 确认选择
const handleConfirm = () => {
  emit('confirm', selectedIds.value)
  handleReset()
}

// 取消
const handleCancel = () => {
  emit('close')
  handleReset()
}

// 重置状态
const handleReset = () => {
  searchKeyword.value = ''
  selectedIds.value = [...props.selectedIds]
}

// 监听props变化，重置选中状态
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    selectedIds.value = [...props.selectedIds]
    searchKeyword.value = ''
  }
})

// 当对话框关闭时重置状态
watch(() => isVisible.value, (newVal) => {
  if (!newVal) {
    handleReset()
  }
})
</script>

<style lang="scss" scoped>
.add-member-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 8px;
  max-height: 500px;
  user-select: none;
  cursor: default;

  .search-input,
  .search-input input {
    user-select: text;
    cursor: text;
  }
}

.contact-list {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 200px;
  max-height: 400px;

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;

    .empty-text {
      font-size: 14px;
      color: #999;
      margin-bottom: 8px;
    }

    .empty-hint {
      font-size: 12px;
      color: #ccc;
    }
  }

  .contact-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    cursor: default;

    .contact-name {
      font-size: 14px;
      color: #333;
      font-weight: 400;
    }
  }
}

/* 滚动条样式 */
.contact-list::-webkit-scrollbar {
  width: 4px;
}

.contact-list::-webkit-scrollbar-track {
  background: transparent;
}

.contact-list::-webkit-scrollbar-thumb {
  background-color: #CCCCCC;
  border-radius: 2px;
}

.contact-list::-webkit-scrollbar-thumb:hover {
  background-color: #BBBBBB;
}
</style>
