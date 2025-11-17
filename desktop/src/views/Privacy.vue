<template>
  <div class="privacy-page">
    <header class="privacy-toolbar">
      <button class="toolbar-btn back-btn" @click="handleBack">
        <img :src="backIcon" alt="返回" />
        <span>返回</span>
      </button>
      <div class="toolbar-info">
        <p class="doc-title">{{ documentTitle }}</p>
        <p class="doc-meta">
          <span>最后更新：{{ formattedUpdatedAt }}</span>
          <span v-if="privacyDoc?.updated_by" class="doc-meta-divider">•</span>
          <span v-if="privacyDoc?.updated_by">编辑：{{ privacyDoc?.updated_by }}</span>
        </p>
      </div>
      <button class="toolbar-btn ghost" @click="fetchPrivacy" :disabled="loading">
        {{ loading ? '刷新中...' : '刷新' }}
      </button>
    </header>

    <section class="privacy-body">
      <div v-if="loading" class="privacy-state">
        <span class="state-dot" />
        <span>正在加载隐私政策...</span>
      </div>
      <div v-else-if="error" class="privacy-state error">
        <p>{{ error }}</p>
        <button class="toolbar-btn primary" @click="fetchPrivacy">重试</button>
      </div>
      <article v-else class="privacy-content" v-html="privacyDoc?.content" />
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
import backIcon from '../assets/image/icon-back.svg'
import { SettingsApi, type DocumentContent } from '../api/settings'
import { toast } from '../utils/toast'

// Props: 接收账号ID（可选，用于多实例页面架构）
interface Props {
  accountId?: string
}

const props = withDefaults(defineProps<Props>(), {
  accountId: undefined
})

const router = useRouter()
const store = useStore()
const loading = ref(true)
const error = ref(null as string | null)
const privacyDoc = ref(null as DocumentContent | null)

const documentTitle = computed(() => privacyDoc.value?.title ?? '隐私政策')
const formattedUpdatedAt = computed(() => {
  const value = privacyDoc.value?.updated_at
  if (!value) {
    return '暂无更新时间'
  }
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }
  const pad = (num: number) => num.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
})

const fetchPrivacy = async () => {
  loading.value = true
  error.value = null
  try {
    const response = await SettingsApi.getPrivacyPolicy()
    if (response.code === 200 && response.data) {
      privacyDoc.value = response.data
    } else {
      throw new Error(response.message || '获取隐私政策失败')
    }
  } catch (err: any) {
    const message = err?.message || '获取隐私政策失败'
    error.value = message
    toast.error(message)
  } finally {
    loading.value = false
  }
}

const handleBack = () => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/settings',
        name: 'Settings',
        params: {},
        query: {}
      }
    })
  } else {
    // 否则使用全局路由
    router.push('/home/settings')
  }
}

onMounted(fetchPrivacy)
</script>

<style lang="scss" scoped>
.privacy-page {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  background: $bg-chat;
}

.privacy-toolbar {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px 32px;
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
}

.toolbar-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.doc-title {
  font-size: 20px;
  font-weight: 600;
  color: #111827;
  margin: 0;
}

.doc-meta {
  font-size: 13px;
  color: #6b7280;
  display: flex;
  gap: 8px;
  align-items: center;
  margin: 0;
}

.doc-meta-divider {
  color: #d1d5db;
}

.toolbar-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: none;
  border-radius: 999px;
  padding: 8px 16px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s ease;
  background: #f1f5f9;
  color: #0f172a;

  &:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 6px 18px rgba(15, 23, 42, 0.12);
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.toolbar-btn.primary {
  background: #2563eb;
  color: #fff;
}

.toolbar-btn.ghost {
  background: transparent;
  border: 1px solid #e2e8f0;
  color: #1d4ed8;
}

.toolbar-btn.back-btn {
  background: #eff6ff;
  color: #1d4ed8;

  img {
    width: 18px;
    height: 18px;
  }
}

.privacy-body {
  flex: 1;
  padding: 24px 32px 32px;
  overflow: hidden;
}

.privacy-content {
  height: 100%;
  padding: 32px;
  background: #fff;
  border-radius: 16px;
  overflow-y: auto;
  color: #1f2937;
  line-height: 1.75;
  box-shadow: 0 12px 40px rgba(15, 23, 42, 0.08);

  :deep(h1),
  :deep(h2),
  :deep(h3) {
    color: #111827;
    margin-top: 24px;
    margin-bottom: 12px;
    font-weight: 600;
  }

  :deep(h1) {
    font-size: 28px;
  }

  :deep(h2) {
    font-size: 22px;
    border-bottom: 1px solid #e5e7eb;
    padding-bottom: 8px;
  }

  :deep(h3) {
    font-size: 18px;
  }

  :deep(p) {
    margin-bottom: 12px;
  }

  :deep(ul),
  :deep(ol) {
    padding-left: 20px;
    margin-bottom: 12px;
  }

  :deep(li) {
    margin-bottom: 4px;
  }

  :deep(a) {
    color: #2563eb;
    text-decoration: underline;
  }
}

.privacy-state {
  height: 100%;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 12px 40px rgba(15, 23, 42, 0.08);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #0f172a;
  font-size: 15px;
}

.privacy-state.error {
  color: #b91c1c;
}

.state-dot {
  width: 12px;
  height: 12px;
  border-radius: 999px;
  background: #2563eb;
  animation: pulse 1s ease-in-out infinite;
}

@keyframes pulse {
  0% {
    opacity: 0.4;
    transform: scale(0.8);
  }
  50% {
    opacity: 1;
    transform: scale(1);
  }
  100% {
    opacity: 0.4;
    transform: scale(0.8);
  }
}
</style>
