<template>
  <SelectableListDialog
    v-model:visible="isVisible"
    title="添加群成员"
    :items="contacts"
    item-key="id"
    :get-label="getContactLabel"
    :get-description="getContactDescription"
    :get-avatar-src="getContactAvatar"
    :get-avatar-text="getContactLabel"
    :enable-search="true"
    search-placeholder="搜索联系人..."
    :initial-selected-ids="initialSelectedIds"
    :get-confirm-text="getConfirmText"
    empty-text="暂无可添加的联系人"
    empty-text-when-search="未找到匹配的联系人"
    empty-hint="请先添加好友"
    @confirm="handleConfirm"
    @close="handleClose"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import SelectableListDialog from './SelectableListDialog.vue'

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

// 确认按钮文本
const initialSelectedIds = computed(() => props.selectedIds ?? [])

const getContactLabel = (contact: Contact) => contact.nickname
const getContactDescription = (contact: Contact) =>
  contact.username ? `@${contact.username}` : ''
const getContactAvatar = (contact: Contact) => contact.avatar

const getConfirmText = (count: number) => {
  if (count === 0) {
    return '请选择联系人'
  }
  return `添加 ${count} 位联系人`
}

const handleConfirm = (selectedIds: string[]) => {
  emit('confirm', selectedIds)
}

const handleClose = () => {
  emit('close')
}
</script>

<style lang="scss" scoped>
/* 样式统一由 SelectableListDialog 管理，这里保留空作用域以兼容 scoped 编译 */
</style>
