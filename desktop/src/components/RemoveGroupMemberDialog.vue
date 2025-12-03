<template>
  <Dialog
    v-model="isVisible"
    title="删除群成员"
    :disable-text-selection="true"
    @confirm="handleConfirm"
    @cancel="handleCancel"
    :confirm-text="confirmText"
    :confirm-disabled="selectedMembers.length === 0"
  >
    <div class="remove-member-content">
      <!-- 搜索框 -->
      <SearchInput
        v-model="searchKeyword"
        placeholder="搜索群成员..."
        @search="handleSearch"
      />

      <!-- 已选中成员预览 -->
      <div v-if="selectedMembers.length > 0" class="selected-members-preview">
        <div class="preview-title">已选中 {{ selectedMembers.length }} 位成员</div>
        <div class="preview-chips">
          <div
            v-for="member in selectedMembers"
            :key="member.userId"
            class="preview-chip"
            @click="handleRemoveFromSelected(member.userId)"
          >
            <span class="chip-name">{{ member.nickname || member.username }}</span>
            <span class="chip-remove">×</span>
          </div>
        </div>
      </div>

      <!-- 群成员列表 -->
      <ScrollContainer class="member-list">
        <div
          v-for="member in filteredMembers"
          :key="member.userId"
          class="member-item"
          :class="{
            'item-disabled': member.role === 'owner',
            'item-selected': isSelected(member.userId)
          }"
          @click="handleToggleMember(member)"
        >
          <input
            type="checkbox"
            :checked="isSelected(member.userId)"
            :disabled="member.role === 'owner'"
            @click.stop="handleToggleMember(member)"
            class="member-checkbox"
          />
          <Avatar
            :src="member.avatarUrl || ''"
            :text="member.nickname || member.username"
            :color-seed="member.userId"
            :size="40"
          />
          <div class="member-info">
            <div class="member-name">{{ member.nickname || member.username }}</div>
            <div class="member-role">{{ getMemberRoleText(member) }}</div>
          </div>
        </div>

        <div v-if="filteredMembers.length === 0" class="empty-state">
          <div class="empty-text">{{ searchKeyword ? '未找到匹配的成员' : '暂无群成员' }}</div>
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
import type { RoomMember } from '@/types/models'

interface Props {
  visible: boolean
  members: RoomMember[]
}

interface Emits {
  (e: 'update:visible', value: boolean): void
  (e: 'confirm', memberIds: string[]): void
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  members: () => []
})

const emit = defineEmits<Emits>()

// 内部可见性状态
const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

// 搜索关键词
const searchKeyword = ref('')

// 已选中的成员
const selectedMemberIds = ref<Set<string>>(new Set())

// 确认按钮文本
const confirmText = computed(() => {
  if (selectedMemberIds.value.size === 0) {
    return '请选择成员'
  }
  return `删除 ${selectedMemberIds.value.size} 位成员`
})

// 已选中的成员列表
const selectedMembers = computed(() => {
  return props.members.filter(member => selectedMemberIds.value.has(member.userId))
})

// 过滤后的成员列表
const filteredMembers = computed(() => {
  const base = props.members.filter(member => member.role !== 'owner')

  if (!searchKeyword.value.trim()) {
    return base
  }

  const keyword = searchKeyword.value.trim().toLowerCase()
  return base.filter(member => {
    const nickname = (member.nickname || '').toLowerCase()
    const username = (member.username || '').toLowerCase()
    return nickname.includes(keyword) || username.includes(keyword)
  })
})

// 检查成员是否已选中
const isSelected = (userId: string): boolean => {
  return selectedMemberIds.value.has(userId)
}

// 切换成员选中状态
const handleToggleMember = (member: RoomMember) => {
  if (member.role === 'owner') {
    return
  }
  if (selectedMemberIds.value.has(member.userId)) {
    selectedMemberIds.value.delete(member.userId)
  } else {
    selectedMemberIds.value.add(member.userId)
  }
}

// 从已选中列表中移除
const handleRemoveFromSelected = (userId: string) => {
  selectedMemberIds.value.delete(userId)
}

// 搜索处理
const handleSearch = (keyword: string) => {
  searchKeyword.value = keyword
}

// 获取成员角色文本
const getMemberRoleText = (member: RoomMember): string => {
  if (member.role === 'owner') {
    return '群主'
  } else if (member.role === 'admin') {
    return '管理员'
  }
  return '成员'
}

// 确认删除
const handleConfirm = () => {
  if (selectedMemberIds.value.size === 0) {
    return
  }
  emit('confirm', Array.from(selectedMemberIds.value))
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
  selectedMemberIds.value.clear()
}

// 当对话框关闭时重置状态
watch(() => props.visible, (newVal) => {
  if (!newVal) {
    handleReset()
  }
})
</script>

<style lang="scss" scoped>
.remove-member-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 12px;
  max-height: 500px;
  user-select: none;
  cursor: default;
  background: rgba(255, 255, 255, 0.4);
  border-radius: 12px;

  // 搜索框正常输入与选中
  .search-input,
  .search-input input {
    user-select: text;
    cursor: text;
  }
}

.selected-members-preview {
  padding: 16px;
  background: linear-gradient(135deg, rgba(0, 191, 166, 0.08), rgba(0, 191, 166, 0.03));
  border: 1px solid rgba(0, 191, 166, 0.15);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 191, 166, 0.08);

  .preview-title {
    font-size: 13px;
    color: #00BFA6;
    margin-bottom: 12px;
    font-weight: 500;
  }

  .preview-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .preview-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: linear-gradient(135deg, #00BFA6, #00A896);
    border-radius: 18px;
    font-size: 12px;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(0, 191, 166, 0.2);

    &:hover {
      background: linear-gradient(135deg, #00A896, #009688);
      box-shadow: 0 4px 12px rgba(0, 191, 166, 0.3);
      transform: translateY(-1px);
    }

    .chip-name {
      color: white;
      font-weight: 500;
    }

    .chip-remove {
      color: white;
      font-size: 16px;
      font-weight: bold;
      opacity: 0.9;
      line-height: 1;
    }
  }
}

.member-list {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 200px;
  max-height: 400px;
}

.member-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-radius: 10px;
  transition: all 0.25s ease;
  cursor: default;
  background: rgba(255, 255, 255, 0.6);
  border: 1px solid transparent;

  &:hover {
    background: rgba(0, 191, 166, 0.06);
    border-color: rgba(0, 191, 166, 0.15);
    box-shadow: 0 4px 12px rgba(0, 191, 166, 0.08);
    transform: translateY(-1px);
  }

  &.item-selected {
    background: rgba(0, 191, 166, 0.12);
    border-color: rgba(0, 191, 166, 0.25);
  }

  .member-checkbox {
    flex-shrink: 0;
    width: 18px;
    height: 18px;
    cursor: pointer;

    &:checked {
      accent-color: #00BFA6;
    }
  }

  .member-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;

    .member-name {
      font-size: 14px;
      font-weight: 500;
      color: #2C2D3A;
      transition: color 0.2s;
    }

    .member-role {
      font-size: 12px;
      color: #686A8A;
      transition: color 0.2s;
    }
  }

  &:hover .member-name,
  &:hover .member-role {
    color: #00BFA6;
  }
}

.item-disabled {
  opacity: 0.5;
  pointer-events: none;
  background: rgba(240, 240, 240, 0.5);

  &:hover {
    background: rgba(240, 240, 240, 0.5);
    border-color: transparent;
    box-shadow: none;
    transform: none;
  }
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;

  .empty-text {
    font-size: 14px;
    color: #999;
    background: rgba(255, 255, 255, 0.5);
    padding: 12px 24px;
    border-radius: 20px;
    border: 1px dashed rgba(0, 191, 166, 0.2);
  }
}

/* 滚动条样式 */
.member-list::-webkit-scrollbar {
  width: 6px;
}

.member-list::-webkit-scrollbar-track {
  background: rgba(0, 191, 166, 0.05);
  border-radius: 3px;
}

.member-list::-webkit-scrollbar-thumb {
  background: linear-gradient(to bottom, rgba(0, 191, 166, 0.4), rgba(0, 191, 166, 0.2));
  border-radius: 3px;
}

.member-list::-webkit-scrollbar-thumb:hover {
  background: linear-gradient(to bottom, rgba(0, 191, 166, 0.6), rgba(0, 191, 166, 0.3));
}
</style>
