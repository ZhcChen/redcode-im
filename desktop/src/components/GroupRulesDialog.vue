<template>
  <Dialog
    v-model="isVisible"
    title="群规"
    :disable-text-selection="true"
    :show-cancel="false"
    confirm-text="关闭"
    width="520px"
    @confirm="handleClose"
    @cancel="handleClose"
  >
    <div class="rules-dialog-content">
      <!-- 添加群规按钮（仅群主/管理员可见） -->
      <div class="action-bar" v-if="canManage">
        <button class="btn-add" @click="handleAddRule">+ 添加群规</button>
      </div>

      <!-- 群规列表 -->
      <div v-if="loading" class="loading-state">加载中...</div>
      <div v-else-if="rules.length === 0" class="empty-state">
        {{ canManage ? '暂无群规，点击上方按钮添加' : '暂无群规' }}
      </div>
      <div v-else class="rules-list">
        <div
          v-for="(rule, index) in rules"
          :key="rule.id"
          class="rule-item"
        >
          <div class="rule-header">
            <span class="rule-index">{{ index + 1 }}</span>
            <span class="rule-title">{{ rule.title }}</span>
            <div class="rule-actions" v-if="canManage">
              <span class="action-btn" @click="handleEditRule(rule)">编辑</span>
              <span class="action-btn danger" @click="handleDeleteRule(rule)">删除</span>
            </div>
          </div>
          <div class="rule-content">{{ rule.content }}</div>
        </div>
      </div>
    </div>

    <!-- 编辑群规对话框 -->
    <Dialog
      v-model="showEditDialog"
      :title="editingRule ? '编辑群规' : '添加群规'"
      confirm-text="保存"
      width="450px"
      @confirm="saveRule"
      @cancel="showEditDialog = false"
    >
      <div class="rule-form">
        <div class="form-item">
          <label>标题</label>
          <input
            v-model="ruleTitle"
            type="text"
            placeholder="请输入群规标题"
            maxlength="50"
          />
        </div>
        <div class="form-item">
          <label>内容</label>
          <textarea
            v-model="ruleContent"
            placeholder="请输入群规内容"
            rows="5"
            maxlength="500"
          ></textarea>
        </div>
      </div>
    </Dialog>

    <!-- 确认删除对话框 -->
    <ConfirmDialog
      v-model:visible="showDeleteConfirm"
      title="删除群规"
      :message="`确定要删除群规「${pendingDeleteRule?.title}」吗？`"
      confirm-text="删除"
      :danger="true"
      @confirm="confirmDeleteRule"
    />
  </Dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Dialog from './Dialog.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import { GroupApi, type GroupRule } from '@/api/group'
import { useToast } from '@/hooks/useToast'

interface Props {
  visible: boolean
  roomId: string
  canManage?: boolean
}

interface Emits {
  (e: 'update:visible', visible: boolean): void
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  canManage: false
})
const emit = defineEmits<Emits>()
const { showToast } = useToast()

const isVisible = computed({
  get: () => props.visible,
  set: (value: boolean) => emit('update:visible', value)
})

const loading = ref(false)
const rules = ref<GroupRule[]>([])
const showEditDialog = ref(false)
const showDeleteConfirm = ref(false)
const editingRule = ref<GroupRule | null>(null)
const pendingDeleteRule = ref<GroupRule | null>(null)
const ruleTitle = ref('')
const ruleContent = ref('')

const loadRules = async () => {
  if (!props.roomId) return
  loading.value = true
  try {
    const resp = await GroupApi.listRules({ roomId: props.roomId })
    if (resp.success && resp.data) {
      rules.value = resp.data.filter(r => r.isActive).sort((a, b) => a.orderIndex - b.orderIndex)
    }
  } catch (error) {
    console.error('加载群规失败:', error)
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('close')
}

const handleAddRule = () => {
  editingRule.value = null
  ruleTitle.value = ''
  ruleContent.value = ''
  showEditDialog.value = true
}

const handleEditRule = (rule: GroupRule) => {
  editingRule.value = rule
  ruleTitle.value = rule.title
  ruleContent.value = rule.content
  showEditDialog.value = true
}

const saveRule = async () => {
  const title = ruleTitle.value.trim()
  const content = ruleContent.value.trim()

  if (!title) {
    showToast('请输入群规标题')
    return
  }
  if (!content) {
    showToast('请输入群规内容')
    return
  }

  try {
    if (editingRule.value) {
      // 更新群规
      const resp = await GroupApi.updateRule({
        roomId: props.roomId,
        ruleId: editingRule.value.id,
        title,
        content
      })
      if (resp.success) {
        showToast('群规已更新')
        await loadRules()
      } else {
        showToast(resp.message || '更新失败')
      }
    } else {
      // 创建群规
      const resp = await GroupApi.createRule({
        roomId: props.roomId,
        title,
        content,
        orderIndex: rules.value.length
      })
      if (resp.success) {
        showToast('群规已添加')
        await loadRules()
      } else {
        showToast(resp.message || '添加失败')
      }
    }
  } catch (error) {
    console.error('保存群规失败:', error)
    showToast('保存失败')
  }

  showEditDialog.value = false
}

const handleDeleteRule = (rule: GroupRule) => {
  pendingDeleteRule.value = rule
  showDeleteConfirm.value = true
}

const confirmDeleteRule = async () => {
  if (!pendingDeleteRule.value) return

  try {
    const resp = await GroupApi.deleteRule({
      roomId: props.roomId,
      ruleId: pendingDeleteRule.value.id
    })
    if (resp.success) {
      showToast('群规已删除')
      await loadRules()
    } else {
      showToast(resp.message || '删除失败')
    }
  } catch (error) {
    console.error('删除群规失败:', error)
    showToast('删除失败')
  }

  pendingDeleteRule.value = null
  showDeleteConfirm.value = false
}

watch(() => props.visible, (visible) => {
  if (visible) {
    loadRules()
  }
})
</script>

<style lang="scss" scoped>
.rules-dialog-content {
  padding: 0 4px;
}

.action-bar {
  margin-bottom: 16px;

  .btn-add {
    padding: 8px 16px;
    background: #1890ff;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;

    &:hover {
      opacity: 0.9;
    }
  }
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 40px;
  color: #999;
  font-size: 14px;
}

.rules-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-height: 400px;
  overflow-y: auto;
}

.rule-item {
  padding: 12px 16px;
  background: #f9f9f9;
  border-radius: 8px;
}

.rule-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.rule-index {
  width: 22px;
  height: 22px;
  background: #1890ff;
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 500;
  flex-shrink: 0;
}

.rule-title {
  font-size: 14px;
  font-weight: 500;
  color: #333;
  flex: 1;
}

.rule-actions {
  display: flex;
  gap: 12px;
}

.action-btn {
  font-size: 13px;
  color: #1890ff;
  cursor: pointer;

  &:hover {
    opacity: 0.8;
  }

  &.danger {
    color: #ff4757;
  }
}

.rule-content {
  font-size: 14px;
  color: #666;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.rule-form {
  padding: 8px 0;
}

.form-item {
  margin-bottom: 16px;

  &:last-child {
    margin-bottom: 0;
  }

  label {
    display: block;
    font-size: 14px;
    color: #333;
    margin-bottom: 8px;
  }

  input,
  textarea {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d9d9d9;
    border-radius: 4px;
    font-size: 14px;
    outline: none;
    resize: vertical;
    font-family: inherit;

    &:focus {
      border-color: #1890ff;
    }
  }
}
</style>
