<template>
  <Mask :visible="visible" :z-index="12000" @update:visible="handleVisibleChange" @close="handleClose">
    <div class="add-member-dialog">
      <!-- 左侧 -->
      <div class="left-section">
        <!-- 搜索框 -->
        <div class="search-wrapper">
          <SearchInput
            v-model="searchKeyword"
            placeholder="搜索联系人..."
          />
        </div>

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
            <div class="contact-info">
              <Avatar :src="contact.avatar" :text="contact.nickname" :color-seed="contact.id" :size="40" />
              <div class="name">{{ contact.nickname }}</div>
            </div>
            <BRadio :model-value="isSelected(contact.id)" />
          </div>
        </ScrollContainer>
      </div>

      <!-- 右侧 -->
      <div class="right-section">
        <!-- 标题行 -->
        <div class="header">
          <div class="title">添加群成员</div>
          <div class="count">已选择{{ selectedContacts.length }}位联系人</div>
        </div>

        <!-- 已选择的联系人 -->
        <ScrollContainer class="selected-members">
          <div
            v-for="contact in selectedContacts"
            :key="contact.id"
            class="selected-member"
            @click="removeContact(contact.id)"
          >
            <Avatar :src="contact.avatar" :text="contact.nickname" :color-seed="contact.id" :size="40" />
            <div class="member-name">{{ contact.nickname }}</div>
            <div class="remove-btn">×</div>
          </div>
        </ScrollContainer>

        <!-- 操作按钮 -->
        <div class="actions">
          <button class="cancel-btn" @click="handleClose">取消</button>
          <button class="confirm-btn" :disabled="selectedContacts.length === 0" @click="handleConfirm">
            确定
          </button>
        </div>
      </div>
    </div>
  </Mask>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import Mask from './Mask.vue'
import SearchInput from './SearchInput.vue'
import BRadio from './BRadio.vue'
import Avatar from './Avatar.vue'
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

// 搜索关键词
const searchKeyword = ref('')

// 选中的联系人ID列表
const selectedIds = ref<string[]>([...props.selectedIds])

// 过滤后的联系人列表
const filteredContacts = computed(() => {
  if (!searchKeyword.value) return props.contacts

  return props.contacts.filter(contact =>
    contact.nickname.toLowerCase().includes(searchKeyword.value.toLowerCase()) ||
    (contact.username && contact.username.toLowerCase().includes(searchKeyword.value.toLowerCase()))
  )
})

// 选中的联系人详情列表
const selectedContacts = computed(() => {
  return props.contacts.filter(contact => selectedIds.value.includes(contact.id))
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

// 移除选中的联系人
const removeContact = (contactId: string) => {
  const index = selectedIds.value.indexOf(contactId)
  if (index > -1) {
    selectedIds.value.splice(index, 1)
  }
}

// 处理visible变化
const handleVisibleChange = (newVisible: boolean) => {
  emit('update:visible', newVisible)
}

// 关闭弹窗
const handleClose = () => {
  emit('update:visible', false)
  emit('close')
}

// 确认选择
const handleConfirm = () => {
  emit('confirm', selectedIds.value)
  handleClose()
}

// 监听props变化，重置选中状态
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    selectedIds.value = [...props.selectedIds]
    searchKeyword.value = ''
  }
})
</script>

<style lang="scss" scoped>
.add-member-dialog {
  width: 800px;
  height: 600px;
  background: white;
  border-radius: 12px;
  display: flex;
  overflow: hidden;
}

.left-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  border-right: 1px solid #f0f0f0;

  .search-wrapper {
    padding: 20px;
    border-bottom: 1px solid #f0f0f0;
  }

  .contact-list {
    flex: 1;
    padding: 0 20px;

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
      justify-content: space-between;
      padding: 12px 0;
      border-bottom: 1px solid #f8f8f8;
      transition: background-color 0.2s;

      &:hover {
        background-color: #f8f9fa;
        border-radius: 8px;
        padding: 12px 8px;
        margin: 0 -8px;
      }

      .contact-info {
        display: flex;
        align-items: center;
        gap: 12px;

        .name {
          font-size: 14px;
          color: #333;
          font-weight: 400;
        }
      }
    }
  }
}

.right-section {
  width: 300px;
  display: flex;
  flex-direction: column;

  .header {
    padding: 20px;
    border-bottom: 1px solid #f0f0f0;
    display: flex;
    align-items: center;
    justify-content: space-between;

    .title {
      font-size: 16px;
      font-weight: 600;
      color: #333;
    }

    .count {
      font-size: 12px;
      color: #666;
    }
  }

  .selected-members {
    flex: 1;
    padding: 20px;
    display: flex;
    flex-wrap: wrap;
    gap: 20px; /* 修改间距为20px */
    align-content: flex-start;

    .selected-member {
      width: calc((100% - 40px) / 3); /* 一行3个，减去两个间距(20px * 2 = 40px) */
      display: flex;
      flex-direction: column;
      align-items: center;
      position: relative;

      .member-name {
        font-size: 11px; /* 稍微减小字体 */
        color: #333;
        text-align: center;
        line-height: 1.2;
        max-width: 100%;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        margin-top: 6px; /* 添加与Avatar组件的间距 */
      }

      .remove-btn {
        position: absolute;
        top: -5px;
        right: 5px;
        width: 20px;
        height: 20px;
        background: #ff4757;
        color: white;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 14px;
        font-weight: bold;
        opacity: 0;
        transition: opacity 0.2s;
      }

      &:hover .remove-btn {
        opacity: 1;
      }
    }
  }

  .actions {
    padding: 20px;
    display: flex;
    gap: 12px;
    border-top: 1px solid #f0f0f0;

    .cancel-btn,
    .confirm-btn {
      flex: 1;
      height: 40px;
      border-radius: 8px;
      border: none;
      font-size: 14px;
      transition: all 0.2s;
    }

    .cancel-btn {
      background: #f8f9fa;
      color: #666;

      &:hover {
        background: #e9ecef;
      }
    }

    .confirm-btn {
      background: var(--primary-color, #007bff);
      color: white;

      &:hover:not(:disabled) {
        opacity: 0.9;
      }

      &:disabled {
        background: #ccc;
        cursor: not-allowed;
      }
    }
  }
}
</style>
