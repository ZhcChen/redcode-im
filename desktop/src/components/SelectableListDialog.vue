<template>
  <Dialog
    v-model="isVisible"
    :title="title"
    :disable-text-selection="true"
    :confirm-text="confirmTextComputed"
    :confirm-disabled="disableConfirmWhenEmpty && selectedIds.length === 0"
    :width="width"
    @confirm="handleConfirm"
    @cancel="handleCancel"
  >
    <div class="selectable-list-content">
      <SearchInput
        v-if="enableSearch"
        v-model="searchKeyword"
        :placeholder="searchPlaceholder"
      />

      <ScrollContainer class="selectable-list">
        <div v-if="filteredItems.length === 0" class="empty-state">
          <div class="empty-text">
            {{ searchKeyword ? emptyTextWhenSearch : emptyText }}
          </div>
          <div v-if="!searchKeyword && emptyHint" class="empty-hint">
            {{ emptyHint }}
          </div>
        </div>

        <div
          v-for="item in filteredItems"
          :key="getKey(item)"
          class="selectable-item"
          @click="toggleItem(item)"
        >
          <slot
            name="item"
            :item="item"
            :selected="isSelected(getKey(item))"
          >
            <BCheckbox
              :model-value="isSelected(getKey(item))"
            />
            <Avatar
              v-if="showAvatar"
              :src="getAvatarSrc(item) || ''"
              :text="getAvatarText(item)"
              :color-seed="getKey(item)"
              :size="40"
            />
            <div class="item-main">
              <div class="item-label">
                {{ getLabel(item) }}
              </div>
              <div v-if="getDescription(item)" class="item-desc">
                {{ getDescription(item) }}
              </div>
            </div>
          </slot>
        </div>
      </ScrollContainer>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import SearchInput from './SearchInput.vue'
import ScrollContainer from './ScrollContainer.vue'
import Avatar from './Avatar.vue'
import BCheckbox from './BCheckbox.vue'

interface Props<T = any> {
  visible: boolean
  title: string
  items: T[]
  itemKey: string | ((item: T) => string)
  getLabel?: (item: T) => string
  getDescription?: (item: T) => string
  getAvatarSrc?: (item: T) => string | null | undefined
  getAvatarText?: (item: T) => string
  confirmText?: string
  getConfirmText?: (count: number) => string
  enableSearch?: boolean
  searchPlaceholder?: string
  initialSelectedIds?: string[]
  emptyText?: string
  emptyTextWhenSearch?: string
  emptyHint?: string
  filterFn?: (item: T, keyword: string) => boolean
  width?: string
  showAvatar?: boolean
  disableConfirmWhenEmpty?: boolean
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
  (e: 'confirm', selectedIds: string[]): void
}

const props = withDefaults(defineProps<Props>(), {
  getLabel: (item: any) => String(item?.name ?? ''),
  getDescription: () => '',
  getAvatarSrc: () => '',
  getAvatarText: (item: any) => String(item?.name ?? ''),
  confirmText: '确定',
  enableSearch: true,
  searchPlaceholder: '搜索...',
  initialSelectedIds: () => [],
  emptyText: '暂无数据',
  emptyTextWhenSearch: '未找到匹配的结果',
  emptyHint: '',
  width: '500px',
  showAvatar: true,
  disableConfirmWhenEmpty: true
})

const emit = defineEmits<Emits>()

const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

const searchKeyword = ref('')
const selectedIds = ref<string[]>([...props.initialSelectedIds])

const getKey = (item: any): string => {
  if (typeof props.itemKey === 'function') {
    return props.itemKey(item)
  }
  const key = (item as any)?.[props.itemKey]
  return typeof key === 'string' ? key : String(key ?? '')
}

const isSelected = (id: string) => selectedIds.value.includes(id)

const toggleItem = (item: any) => {
  const id = getKey(item)
  const index = selectedIds.value.indexOf(id)
  if (index > -1) {
    selectedIds.value.splice(index, 1)
  } else {
    selectedIds.value.push(id)
  }
}

const getLabel = (item: any) => props.getLabel?.(item) ?? ''
const getDescription = (item: any) => props.getDescription?.(item) ?? ''
const getAvatarSrc = (item: any) => props.getAvatarSrc?.(item) ?? ''
const getAvatarText = (item: any) => props.getAvatarText?.(item) ?? ''

const confirmTextComputed = computed(() => {
  if (props.getConfirmText) {
    return props.getConfirmText(selectedIds.value.length)
  }
  return props.confirmText || '确定'
})

const filteredItems = computed(() => {
  if (!props.enableSearch || !searchKeyword.value) {
    return props.items
  }

  const keyword = searchKeyword.value.trim().toLowerCase()
  if (!keyword) {
    return props.items
  }

  if (props.filterFn) {
    return props.items.filter((item) => props.filterFn!(item, keyword))
  }

  return props.items.filter((item) => {
    const label = getLabel(item).toLowerCase()
    const desc = getDescription(item).toLowerCase()
    return label.includes(keyword) || desc.includes(keyword)
  })
})

const handleConfirm = () => {
  emit('confirm', [...selectedIds.value])
  handleReset()
}

const handleCancel = () => {
  emit('close')
  handleReset()
}

const handleReset = () => {
  searchKeyword.value = ''
  selectedIds.value = [...props.initialSelectedIds]
}

watch(
  () => props.visible,
  (newVisible) => {
    if (newVisible) {
      selectedIds.value = [...props.initialSelectedIds]
      searchKeyword.value = ''
    }
  }
)

watch(
  () => isVisible.value,
  (newVal) => {
    if (!newVal) {
      handleReset()
    }
  }
)
</script>

<style scoped lang="scss">
.selectable-list-content {
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

.selectable-list {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 200px;
  max-height: 400px;
}

.selectable-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  cursor: default;

  .item-main {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .item-label {
    font-size: 14px;
    color: #333;
    font-weight: 500;
  }

  .item-desc {
    font-size: 12px;
    color: #666;
  }
}

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

.selectable-list::-webkit-scrollbar {
  width: 4px;
}

.selectable-list::-webkit-scrollbar-track {
  background: transparent;
}

.selectable-list::-webkit-scrollbar-thumb {
  background-color: #cccccc;
  border-radius: 2px;
}

.selectable-list::-webkit-scrollbar-thumb:hover {
  background-color: #bbbbbb;
}
</style>

