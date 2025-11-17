<template>
  <div class="emoji-picker" v-if="show">
    <div class="emoji-tabs">
      <div
        v-for="(tab, index) in tabs"
        :key="index"
        class="emoji-tab"
        :class="{ active: selectedTabIndex === index }"
        @click="selectedTabIndex = index"
      >
        <img
          v-if="tab.icon && tab.icon.startsWith('http')"
          :src="tab.icon"
          alt=""
          class="tab-icon"
        />
        <span v-else-if="tab.icon" class="tab-icon-emoji">{{ tab.icon }}</span>
        <span class="tab-label">{{ tab.label }}</span>
      </div>
    </div>
    <div class="emoji-content">
      <!-- 搜索 tab -->
      <div v-if="selectedTabIndex === 0" class="search-tab">
        <div class="search-input-wrapper">
          <input
            v-model="searchKeyword"
            type="text"
            class="search-input"
            placeholder="搜索表情包或套件..."
            @input="handleSearch"
          />
        </div>
        <div v-if="searchLoading" class="loading">搜索中...</div>
        <div v-else-if="searchResults.length === 0 && searchKeyword" class="empty-state">
          未找到相关表情包
        </div>
        <div v-else-if="searchResults.length > 0" class="search-results">
          <div
            v-for="result in searchResults"
            :key="result.id"
            class="search-result-item"
            @click="handleSearchResultClick(result)"
          >
            <img
              v-if="result.icon_url"
              :src="result.icon_url"
              alt=""
              class="result-icon"
            />
            <span v-else class="result-icon-placeholder">📦</span>
            <div class="result-info">
              <div class="result-name">
                {{ result.name }}
                <span class="result-type">
                  {{ result.pack_type === 1 ? '套件' : '表情包' }}
                </span>
              </div>
              <div v-if="result.description" class="result-desc">
                {{ result.description }}
              </div>
            </div>
          </div>
        </div>
        <div v-else class="empty-state">输入关键词搜索表情包或套件</div>
      </div>
      <!-- 其他 tab -->
      <div v-else>
        <div v-if="loadingPacks && selectedTabIndex === 1" class="loading">
          加载中...
        </div>
        <div v-else class="emoji-grid" :class="getGridClass()">
          <div
            v-for="(item, index) in currentItems"
            :key="index"
            class="emoji-item"
            @click="selectEmoji(item)"
            :title="item.name || ''"
          >
            <CachedEmojiImage
              v-if="item.type === 'image'"
              :image-url="item.value"
            />
            <span v-else class="emoji-text">{{ item.value }}</span>
          </div>
          <div
            v-if="currentItems.length === 0 && selectedTabIndex === 1"
            class="empty-state"
          >
            暂无自定义表情<br />请在设置中添加表情包
          </div>
        </div>
      </div>
    </div>

    <!-- 添加确认对话框 -->
    <div v-if="showAddConfirm" class="add-confirm-overlay" @click="showAddConfirm = false">
      <div class="add-confirm-dialog" @click.stop>
        <div class="confirm-header">
          <h3>{{ addConfirmTitle }}</h3>
        </div>
        <div class="confirm-content">
          <p>{{ addConfirmMessage }}</p>
        </div>
        <div class="confirm-actions">
          <button class="btn-cancel" @click="showAddConfirm = false">取消</button>
          <button class="btn-confirm" @click="handleConfirmAdd">确定</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, h, defineComponent } from 'vue'
import { api, type EmojiPack, type EmojiItem } from '../api'
import { EmojiItemApi } from '../api/emoji-item'
import { toast } from '../utils/toast'

interface Emoji {
  emoji: string
  code: string
  name: string
}

interface TabItem {
  type: 'search' | 'emoji' | 'custom' | 'pack'
  icon: string | null
  label: string
  pack?: EmojiPack
}

interface EmojiDisplayItem {
  type: 'emoji' | 'image'
  value: string
  name?: string
}

// Props
const props = defineProps<{
  show: boolean
}>()

// Emits
const emit = defineEmits<{
  select: [emoji: string]
  close: []
}>()

const selectedTabIndex = ref(0)
const userPacks = ref<EmojiPack[]>([])
const loadingPacks = ref(false)

// 搜索相关
const searchKeyword = ref('')
const searchResults = ref<EmojiPack[]>([])
const searchLoading = ref(false)
const searchTimeout = ref<number | null>(null)

// 添加确认对话框
const showAddConfirm = ref(false)
const addConfirmTitle = ref('')
const addConfirmMessage = ref('')
const pendingAddPack = ref<EmojiPack | null>(null)
const pendingAddType = ref<'pack' | 'suite'>('pack')

// 常用表情列表
const emojiList: Emoji[] = [
  { emoji: '😀', code: 'grinning', name: '开心' },
  { emoji: '😃', code: 'grinning_big', name: '大笑' },
  { emoji: '😄', code: 'grinning_squinting', name: '眯眼笑' },
  { emoji: '😁', code: 'beaming', name: '露齿笑' },
  { emoji: '😆', code: 'laughing', name: '哈哈' },
  { emoji: '😅', code: 'grinning_sweat', name: '苦笑' },
  { emoji: '🤣', code: 'rolling_laughing', name: '捧腹大笑' },
  { emoji: '😂', code: 'joy', name: '笑哭' },
  { emoji: '🙂', code: 'slightly_smiling', name: '微笑' },
  { emoji: '🙃', code: 'upside_down', name: '颠倒笑脸' },
  { emoji: '😉', code: 'winking', name: '眨眼' },
  { emoji: '😊', code: 'blush', name: '害羞' },
  { emoji: '😇', code: 'innocent', name: '天真' },
  { emoji: '🥰', code: 'smiling_hearts', name: '花痴' },
  { emoji: '😍', code: 'heart_eyes', name: '心形眼' },
  { emoji: '🤩', code: 'star_struck', name: '星星眼' },
  { emoji: '😘', code: 'kissing_heart', name: '飞吻' },
  { emoji: '😗', code: 'kissing', name: '亲吻' },
  { emoji: '☺️', code: 'relaxed', name: '满足' },
  { emoji: '😚', code: 'kissing_closed_eyes', name: '闭眼亲吻' },
  { emoji: '😙', code: 'kissing_smiling_eyes', name: '眯眼亲吻' },
  { emoji: '🥲', code: 'smiling_tear', name: '含泪微笑' },
  { emoji: '😋', code: 'yum', name: '美味' },
  { emoji: '😛', code: 'stuck_out_tongue', name: '吐舌' },
  { emoji: '😜', code: 'stuck_out_tongue_winking', name: '眨眼吐舌' },
  { emoji: '🤪', code: 'zany', name: '疯狂' },
  { emoji: '😝', code: 'stuck_out_tongue_closed_eyes', name: '闭眼吐舌' },
  { emoji: '🤑', code: 'money_mouth', name: '财迷' },
  { emoji: '🤗', code: 'hugs', name: '拥抱' },
  { emoji: '🤭', code: 'hand_over_mouth', name: '捂嘴' },
  { emoji: '🤫', code: 'shushing', name: '嘘' },
  { emoji: '🤔', code: 'thinking', name: '思考' },
  { emoji: '🤐', code: 'zipper_mouth', name: '闭嘴' },
  { emoji: '🤨', code: 'raised_eyebrow', name: '质疑' },
  { emoji: '😐', code: 'neutral', name: '面无表情' },
  { emoji: '😑', code: 'expressionless', name: '木然' },
  { emoji: '😶', code: 'no_mouth', name: '无言' },
  { emoji: '😏', code: 'smirk', name: '得意' },
  { emoji: '😒', code: 'unamused', name: '不悦' },
  { emoji: '🙄', code: 'eye_roll', name: '翻白眼' },
  { emoji: '😬', code: 'grimacing', name: '做鬼脸' },
  { emoji: '🤥', code: 'lying', name: '撒谎' },
  { emoji: '😔', code: 'pensive', name: '沉思' },
  { emoji: '😪', code: 'sleepy', name: '困倦' },
  { emoji: '🤤', code: 'drooling', name: '流口水' },
  { emoji: '😴', code: 'sleeping', name: '睡觉' },
  { emoji: '😷', code: 'mask', name: '口罩' },
  { emoji: '🤒', code: 'thermometer_face', name: '发烧' },
  { emoji: '🤕', code: 'head_bandage', name: '受伤' },
  { emoji: '🤢', code: 'nauseated', name: '恶心' },
  { emoji: '🤮', code: 'vomiting', name: '呕吐' },
  { emoji: '🤧', code: 'sneezing', name: '打喷嚏' },
  { emoji: '🥵', code: 'hot', name: '热' },
  { emoji: '🥶', code: 'cold', name: '冷' },
  { emoji: '🥴', code: 'woozy', name: '头晕' },
  { emoji: '😵', code: 'dizzy_face', name: '晕' },
  { emoji: '🤯', code: 'exploding_head', name: '震惊' },
  { emoji: '🤠', code: 'cowboy', name: '牛仔' },
  { emoji: '🥳', code: 'partying', name: '庆祝' },
  { emoji: '🥸', code: 'disguised', name: '伪装' },
  { emoji: '😎', code: 'sunglasses', name: '墨镜' },
  { emoji: '🤓', code: 'nerd', name: '书呆子' },
  { emoji: '🧐', code: 'monocle', name: '单片眼镜' },
  { emoji: '😕', code: 'confused', name: '困惑' },
  { emoji: '😟', code: 'worried', name: '担心' },
  { emoji: '🙁', code: 'frowning', name: '皱眉' },
  { emoji: '☹️', code: 'frowning2', name: '皱眉2' },
  { emoji: '😮', code: 'open_mouth', name: '张嘴' },
  { emoji: '😯', code: 'hushed', name: '惊讶' },
  { emoji: '😲', code: 'astonished', name: '震惊' },
  { emoji: '😳', code: 'flushed', name: '脸红' },
  { emoji: '🥺', code: 'pleading', name: '恳求' },
  { emoji: '😦', code: 'frowning_open_mouth', name: '皱眉张嘴' },
  { emoji: '😧', code: 'anguished', name: '痛苦' },
  { emoji: '😨', code: 'fearful', name: '恐惧' },
  { emoji: '😰', code: 'cold_sweat', name: '冷汗' },
  { emoji: '😥', code: 'disappointed_relieved', name: '失望但放心' },
  { emoji: '😢', code: 'cry', name: '哭泣' },
  { emoji: '😭', code: 'sob', name: '大哭' },
  { emoji: '😱', code: 'scream', name: '尖叫' },
  { emoji: '😖', code: 'confounded', name: '困扰' },
  { emoji: '😣', code: 'persevere', name: '坚持' },
  { emoji: '😞', code: 'disappointed', name: '失望' },
  { emoji: '😓', code: 'sweat', name: '汗' },
  { emoji: '😩', code: 'weary', name: '疲惫' },
  { emoji: '😫', code: 'tired_face', name: '累' },
  { emoji: '🥱', code: 'yawning', name: '打哈欠' },
  { emoji: '😤', code: 'triumph', name: '胜利' },
  { emoji: '😡', code: 'rage', name: '愤怒' },
  { emoji: '😠', code: 'angry', name: '生气' },
  { emoji: '🤬', code: 'swearing', name: '骂人' },
  { emoji: '👍', code: 'thumbs_up', name: '点赞' },
  { emoji: '👎', code: 'thumbs_down', name: '点踩' },
  { emoji: '👏', code: 'clap', name: '鼓掌' },
  { emoji: '🙏', code: 'pray', name: '祈祷' },
  { emoji: '❤️', code: 'heart', name: '红心' },
  { emoji: '💔', code: 'broken_heart', name: '心碎' },
  { emoji: '💕', code: 'two_hearts', name: '双心' },
  { emoji: '💖', code: 'sparkling_heart', name: '闪亮心' },
  { emoji: '💗', code: 'growing_heart', name: '成长心' },
  { emoji: '💘', code: 'cupid', name: '丘比特' },
  { emoji: '💙', code: 'blue_heart', name: '蓝心' },
  { emoji: '💚', code: 'green_heart', name: '绿心' },
  { emoji: '💛', code: 'yellow_heart', name: '黄心' },
  { emoji: '🧡', code: 'orange_heart', name: '橙心' },
  { emoji: '💜', code: 'purple_heart', name: '紫心' },
  { emoji: '🖤', code: 'black_heart', name: '黑心' },
  { emoji: '🤍', code: 'white_heart', name: '白心' },
  { emoji: '🤎', code: 'brown_heart', name: '棕心' },
  { emoji: '💯', code: 'hundred', name: '100' },
  { emoji: '💢', code: 'anger', name: '愤怒符号' },
  { emoji: '💥', code: 'boom', name: '爆炸' },
  { emoji: '💫', code: 'dizzy', name: '眩晕' },
  { emoji: '💦', code: 'sweat_drops', name: '汗滴' },
  { emoji: '💨', code: 'dash', name: '风' },
  { emoji: '🕳️', code: 'hole', name: '洞' },
  { emoji: '💤', code: 'zzz', name: 'ZZZ' },
  { emoji: '👋', code: 'wave', name: '挥手' },
  { emoji: '🤚', code: 'raised_back_of_hand', name: '手背' },
  { emoji: '🖐️', code: 'hand_splayed', name: '张开手' },
  { emoji: '✋', code: 'raised_hand', name: '举手' },
  { emoji: '🖖', code: 'vulcan', name: '瓦肯手势' },
  { emoji: '👌', code: 'ok_hand', name: 'OK' },
  { emoji: '🤌', code: 'pinched_fingers', name: '捏手指' },
  { emoji: '🤏', code: 'pinching_hand', name: '捏' },
  { emoji: '✌️', code: 'peace', name: '和平' },
  { emoji: '🤞', code: 'fingers_crossed', name: '交叉手指' },
  { emoji: '🤟', code: 'love_you', name: '爱你' },
  { emoji: '🤘', code: 'rock', name: '摇滚' },
  { emoji: '🤙', code: 'call_me', name: '打电话' },
  { emoji: '👈', code: 'point_left', name: '左指' },
  { emoji: '👉', code: 'point_right', name: '右指' },
  { emoji: '👆', code: 'point_up_2', name: '上指' },
  { emoji: '🖕', code: 'middle_finger', name: '中指' },
  { emoji: '👇', code: 'point_down', name: '下指' },
  { emoji: '☝️', code: 'point_up', name: '食指' },
  { emoji: '✊', code: 'fist', name: '拳头' },
  { emoji: '👊', code: 'punch', name: '出拳' },
  { emoji: '🤛', code: 'left_fist', name: '左拳' },
  { emoji: '🤜', code: 'right_fist', name: '右拳' }
]

// 构建 tabs（搜索 tab 在第一个）
const tabs = computed<TabItem[]>(() => {
  const result: TabItem[] = [
    {
      type: 'search',
      icon: '🔍',
      label: '搜索'
    },
    {
      type: 'emoji',
      icon: '😀',
      label: 'Emoji'
    },
    {
      type: 'custom',
      icon: '🎨',
      label: '自定义'
    }
  ]

  // 添加用户表情包 tabs
  for (const pack of userPacks.value) {
    result.push({
      type: 'pack',
      icon: pack.icon_url || null,
      label: pack.name,
      pack
    })
  }

  return result
})

// 获取当前显示的表情项
const currentItems = computed<EmojiDisplayItem[]>(() => {
  const tab = tabs.value[selectedTabIndex.value]
  if (!tab) return []

  switch (tab.type) {
    case 'search':
      return [] // 搜索 tab 不显示表情项
    case 'emoji':
      return emojiList.map(e => ({
        type: 'emoji' as const,
        value: e.emoji,
        name: e.name
      }))
    case 'custom':
      // 收集所有用户表情包中的表情项
      const allItems: EmojiDisplayItem[] = []
      for (const pack of userPacks.value) {
        if (pack.items) {
          for (const item of pack.items) {
            allItems.push({
              type: 'image',
              value: item.image_url,
              name: item.name || undefined
            })
          }
        }
      }
      return allItems
    case 'pack':
      if (tab.pack?.items) {
        return tab.pack.items.map(item => ({
          type: 'image' as const,
          value: item.image_url,
          name: item.name || undefined
        }))
      }
      return []
  }
})

// 获取网格类名
const getGridClass = () => {
  const tab = tabs.value[selectedTabIndex.value]
  if (tab?.type === 'emoji') {
    return 'emoji-grid-8'
  }
  return 'emoji-grid-6'
}

// 搜索功能
const handleSearch = () => {
  if (searchTimeout.value) {
    clearTimeout(searchTimeout.value)
  }

  if (!searchKeyword.value.trim()) {
    searchResults.value = []
    return
  }

  searchTimeout.value = window.setTimeout(async () => {
    try {
      searchLoading.value = true
      searchResults.value = await api.emojiPack.searchPacks(searchKeyword.value.trim())
    } catch (error) {
      console.error('搜索失败:', error)
      searchResults.value = []
    } finally {
      searchLoading.value = false
    }
  }, 300)
}

// 点击搜索结果
const handleSearchResultClick = (pack: EmojiPack) => {
  pendingAddPack.value = pack
  if (pack.pack_type === 1) {
    // 套件
    pendingAddType.value = 'suite'
    addConfirmTitle.value = '添加表情包套件'
    addConfirmMessage.value = `确定要添加套件"${pack.name}"吗？这将添加套件下的所有表情包。`
  } else {
    // 单个表情包
    pendingAddType.value = 'pack'
    addConfirmTitle.value = '添加表情包'
    addConfirmMessage.value = `确定要添加表情包"${pack.name}"到自定义表情吗？`
  }
  showAddConfirm.value = true
}

// 确认添加
const handleConfirmAdd = async () => {
  if (!pendingAddPack.value) return

  try {
    if (pendingAddType.value === 'suite') {
      const result = await api.emojiPack.addUserSuite(pendingAddPack.value.id)
      toast.success(`成功添加 ${result.count} 个表情包`)
    } else {
      await api.emojiPack.addUserPack(pendingAddPack.value.id)
      toast.success('添加成功')
    }
    showAddConfirm.value = false
    pendingAddPack.value = null
    // 重新加载用户表情包
    await loadUserPacks()
    // 切换到自定义 tab
    const customTabIndex = tabs.value.findIndex(t => t.type === 'custom')
    if (customTabIndex >= 0) {
      selectedTabIndex.value = customTabIndex
    }
  } catch (error: any) {
    console.error('添加失败:', error)
    toast.error(error?.message || '添加失败，请重试')
  }
}

// 加载用户表情包
const loadUserPacks = async () => {
  loadingPacks.value = true
  try {
    // 使用 list_user_packs API，它已经返回了包含 items 的数据
    const data = await api.emojiPack.getUserPacks()
    userPacks.value = data.map((item) => ({
      ...item.pack,
      items: item.items || []
    }))
  } catch (error) {
    console.error('加载表情包失败:', error)
    userPacks.value = []
  } finally {
    loadingPacks.value = false
  }
}

// 选择表情
const selectEmoji = (item: EmojiDisplayItem) => {
  emit('select', item.value)
  emit('close')
}

// 监听 show 变化，显示时加载表情包
watch(() => props.show, (newVal) => {
  if (newVal) {
    loadUserPacks()
    // 重置搜索
    searchKeyword.value = ''
    searchResults.value = []
  }
})

onMounted(() => {
  if (props.show) {
    loadUserPacks()
  }
})

// 带缓存的表情图片组件（支持 GIF）
const CachedEmojiImage = defineComponent({
  props: {
    imageUrl: {
      type: String,
      required: true
    }
  },
  setup(props) {
    const cachedUrl = ref<string | null>(null)
    const loading = ref(false)
    const error = ref(false)

    const loadEmoji = async () => {
      if (!props.imageUrl) return

      loading.value = true
      error.value = false

      try {
        const url = await EmojiItemApi.loadAndCacheEmoji(props.imageUrl)
        if (url) {
          cachedUrl.value = url
        } else {
          error.value = true
        }
      } catch (e) {
        console.error('加载表情失败:', e)
        error.value = true
      } finally {
        loading.value = false
      }
    }

    watch(() => props.imageUrl, loadEmoji, { immediate: true })

    return () => {
      if (loading.value) {
        return h('div', { class: 'emoji-loading' }, '...')
      }

      if (error.value || !cachedUrl.value) {
        // 如果缓存失败，直接使用原始 URL（浏览器会自动处理 GIF）
        return h('img', {
          src: props.imageUrl,
          alt: '',
          class: 'emoji-image'
        })
      }

      // 使用缓存的 blob URL（支持 GIF 动画）
      return h('img', {
        src: cachedUrl.value,
        alt: '',
        class: 'emoji-image'
      })
    }
  }
})
</script>

<style lang="scss" scoped>
.emoji-picker {
  position: absolute;
  bottom: 100%;
  left: 0;
  margin-bottom: 8px;
  width: 340px;
  max-height: 300px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  z-index: 1000;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
}

.emoji-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  padding: 8px;
  border-bottom: 1px solid #e5e5e5;
  flex-shrink: 0;
  overflow: hidden;
}

.emoji-tab {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 6px 12px;
  border-radius: 16px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.2s;
  font-size: 12px;
  max-width: 120px;
  min-width: fit-content;
  flex-shrink: 0;

  &:hover {
    background-color: #f5f5f5;
  }

  &.active {
    background-color: rgba(22, 93, 255, 0.1);
    color: #165dff;
    font-weight: 600;
    border: 1px solid #165dff;
  }

  .tab-icon {
    width: 20px;
    height: 20px;
    object-fit: contain;
    flex-shrink: 0;
  }

  .tab-icon-emoji {
    font-size: 18px;
    flex-shrink: 0;
  }

  .tab-label {
    font-size: 12px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.emoji-content {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 10px;
  box-sizing: border-box;

  &::-webkit-scrollbar {
    width: 4px;
  }

  &::-webkit-scrollbar-track {
    background: #f1f1f1;
  }

  &::-webkit-scrollbar-thumb {
    background: #c1c1c1;
    border-radius: 2px;
  }
}

.search-tab {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.search-input-wrapper {
  margin-bottom: 12px;
}

.search-input {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #e5e5e5;
  border-radius: 8px;
  font-size: 14px;
  outline: none;
  box-sizing: border-box;

  &:focus {
    border-color: #165dff;
  }
}

.search-results {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.search-result-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px;
  border-radius: 8px;
  cursor: pointer;
  transition: background-color 0.2s;

  &:hover {
    background-color: #f5f5f5;
  }

  .result-icon {
    width: 40px;
    height: 40px;
    object-fit: contain;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .result-icon-placeholder {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    background: #f5f5f5;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .result-info {
    flex: 1;
    min-width: 0;
  }

  .result-name {
    font-size: 14px;
    font-weight: 500;
    color: #333;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 8px;

    .result-type {
      font-size: 12px;
      color: #999;
      font-weight: normal;
    }
  }

  .result-desc {
    font-size: 12px;
    color: #666;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.loading {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100px;
  color: #999;
}

.emoji-grid {
  display: grid;
  gap: 4px;
  width: 100%;
  box-sizing: border-box;

  &.emoji-grid-8 {
    grid-template-columns: repeat(8, 1fr);
  }

  &.emoji-grid-6 {
    grid-template-columns: repeat(6, 1fr);
  }
}

.emoji-item {
  display: flex;
  align-items: center;
  justify-content: center;
  aspect-ratio: 1;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.2s;
  min-width: 0;
  overflow: hidden;

  &:hover {
    background-color: #f5f5f5;
  }

  &:active {
    background-color: #e0e0e0;
  }

  .emoji-text {
    font-size: 24px;
    line-height: 1;
  }

  .emoji-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 6px;
    display: block;
  }

  .emoji-loading {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    color: #86909c;
  }
}

.empty-state {
  grid-column: 1 / -1;
  text-align: center;
  color: #999;
  padding: 20px;
  font-size: 12px;
  line-height: 1.6;
}

.add-confirm-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
}

.add-confirm-dialog {
  background: white;
  border-radius: 12px;
  padding: 24px;
  min-width: 320px;
  max-width: 400px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
}

.confirm-header {
  margin-bottom: 16px;

  h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #333;
  }
}

.confirm-content {
  margin-bottom: 24px;

  p {
    margin: 0;
    font-size: 14px;
    color: #666;
    line-height: 1.6;
  }
}

.confirm-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
}

.btn-cancel,
.btn-confirm {
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  border: none;
  transition: all 0.2s;
}

.btn-cancel {
  background: #f5f5f5;
  color: #333;

  &:hover {
    background: #e5e5e5;
  }
}

.btn-confirm {
  background: #165dff;
  color: white;

  &:hover {
    background: #0e4fd1;
  }
}
</style>
