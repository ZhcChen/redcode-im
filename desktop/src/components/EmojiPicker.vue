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
        <TabIcon
          v-else-if="tab.icon && (tab.icon === 'search' || tab.icon === 'emoji' || tab.icon === 'custom')"
          :type="tab.icon"
        />
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
        <div
          v-if="
            (loadingPacks && selectedTabIndex === 1) ||
            (tabs[selectedTabIndex]?.type === 'pack' &&
              tabs[selectedTabIndex]?.pack &&
              loadingSuitePacks[tabs[selectedTabIndex].pack.id])
          "
          class="loading"
        >
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
          <div
            v-else-if="
              currentItems.length === 0 &&
              tabs[selectedTabIndex]?.type === 'pack'
            "
            class="empty-state"
          >
            该套件暂无表情<br />请先添加表情包到套件
          </div>
          <div
            v-else-if="
              currentItems.length === 0 &&
              tabs[selectedTabIndex]?.type === 'custom'
            "
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
import { api } from '../api'
import { EmojiItemApi } from '../api/emoji-item'
import type { EmojiPack, EmojiItem } from '../api/emoji-pack'
import { toast } from '../utils/toast'

interface Emoji {
  emoji: string
  code: string
  name: string
}

interface TabItem {
  type: 'search' | 'emoji' | 'custom' | 'pack'
  icon: string | null  // 'search' | 'emoji' | 'custom' | URL
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
const userPacks = ref<EmojiPack[]>([]) // 所有用户表情包（包括单个和套件）
const suitePacksCache = ref<Record<string, Array<{ pack: EmojiPack; items: EmojiItem[] }>>>({}) // 套件下的表情包缓存
const loadingPacks = ref(false)
const loadingSuitePacks = ref<Record<string, boolean>>({}) // 套件加载状态

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
      icon: 'search',
      label: '搜索'
    },
    {
      type: 'emoji',
      icon: 'emoji',
      label: 'Emoji'
    },
    {
      type: 'custom',
      icon: 'custom',
      label: '自定义'
    }
  ]

  // 只添加套件（pack_type === 1）作为动态 tab
  for (const pack of userPacks.value) {
    if (pack.pack_type === 1) {
      result.push({
        type: 'pack',
        icon: pack.icon_url || null,
        label: pack.name,
        pack
      })
    }
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
      // 收集所有独立的单个表情包（pack_type === 0 且 parent_id === null）中的表情项
      // 排除套件（pack_type === 1）和套件下的子表情包（pack_type === 0 但有 parent_id）
      const allItems: EmojiDisplayItem[] = []
      console.log('计算自定义 tab 的表情项，userPacks 数量:', userPacks.value.length)
      for (const pack of userPacks.value) {
        console.log(`检查表情包: id=${pack.id}, name=${pack.name}, pack_type=${pack.pack_type}, parent_id=${pack.parent_id || 'null'}, items数量=${pack.items?.length || 0}, icon_url=${pack.icon_url || '无'}`)
        // 只包含独立的单个表情包：pack_type === 0 且 parent_id === null/undefined
        if (pack.pack_type === 0 && !pack.parent_id) {
          // 如果表情包有 items，使用 items
          if (pack.items && pack.items.length > 0) {
            for (const item of pack.items) {
              if (item.image_url) {
                allItems.push({
                  type: 'image',
                  value: item.image_url,
                  name: item.name || undefined
                })
              }
            }
          } 
          // 如果表情包没有 items 但有 icon_url，使用 icon_url 作为单个表情
          else if (pack.icon_url) {
            allItems.push({
              type: 'image',
              value: pack.icon_url,
              name: pack.name || undefined
            })
          }
        }
      }
      console.log('自定义 tab 的表情项总数:', allItems.length)
      return allItems
    case 'pack':
      // 套件 tab：显示套件下所有子表情包的 icon_url（不是子表情包下的 items）
      if (!tab.pack) return []
      const suiteId = tab.pack.id
      const suitePacks = suitePacksCache.value[suiteId]
      console.log('套件 tab 计算，suiteId:', suiteId, '缓存:', suitePacks)
      if (suitePacks && suitePacks.length > 0) {
        const suiteItems: EmojiDisplayItem[] = []
        console.log('开始处理套件表情包，数量:', suitePacks.length)
        for (const suitePack of suitePacks) {
          const pack = suitePack.pack
          if (pack && pack.icon_url) {
            console.log('处理子表情包:', pack.name, 'icon_url:', pack.icon_url)
            suiteItems.push({
              type: 'image' as const,
              value: pack.icon_url,
              name: pack.name || undefined
            })
          } else {
            console.warn('子表情包没有 icon_url:', pack)
          }
        }
        console.log('套件表情项列表:', suiteItems)
        return suiteItems
      }
      // 如果缓存中没有且未在加载中，异步加载
      if (!loadingSuitePacks.value[suiteId]) {
        console.log('缓存中没有数据，触发加载:', suiteId)
        loadSuitePacks(suiteId)
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

  // 先保存需要使用的值
  const packId = pendingAddPack.value.id
  const addType = pendingAddType.value

  try {
    if (addType === 'suite') {
      const result = await api.emojiPack.addUserSuite(packId)
      toast.success(`成功添加 ${result.count} 个表情包`)
    } else {
      await api.emojiPack.addUserPack(packId)
      toast.success('添加成功')
    }
    showAddConfirm.value = false
    // 重新加载用户表情包
    await loadUserPacks()
    
    // 添加调试日志
    console.log('添加表情包后，userPacks 数据:', userPacks.value)
    const addedPack = userPacks.value.find((p: EmojiPack) => p.id === packId)
    console.log('新添加的表情包:', addedPack)
    if (addedPack) {
      console.log('表情包的 items:', addedPack.items)
      console.log('表情包的 items 数量:', addedPack.items?.length || 0)
    }
    
    // 等待 Vue 响应式更新完成
    await new Promise(resolve => setTimeout(resolve, 100))
    
    // 根据添加类型切换到对应 tab
    if (addType === 'suite') {
      // 套件：切换到新添加的套件 tab
      // 需要等待 tabs 更新后再查找
      await new Promise(resolve => setTimeout(resolve, 100))
      const suiteTabIndex = tabs.value.findIndex((t: TabItem) => t.type === 'pack' && t.pack?.id === packId)
      if (suiteTabIndex >= 0) {
        selectedTabIndex.value = suiteTabIndex
      }
    } else {
      // 单个表情包：切换到自定义 tab
      const customTabIndex = tabs.value.findIndex((t: TabItem) => t.type === 'custom')
      if (customTabIndex >= 0) {
        selectedTabIndex.value = customTabIndex
        // 再次等待，确保 currentItems 计算完成
        await new Promise(resolve => setTimeout(resolve, 50))
        console.log('切换到自定义 tab 后，currentItems:', currentItems.value)
        console.log('自定义 tab 的表情项数量:', currentItems.value.length)
      }
    }
    // 清空待添加的数据
    pendingAddPack.value = null
  } catch (error: any) {
    console.error('添加失败:', error)
    toast.error(error?.message || '添加失败，请重试')
    showAddConfirm.value = false
    pendingAddPack.value = null
  }
}

// 加载套件下的表情包
const loadSuitePacks = async (suiteId: string) => {
  if (suitePacksCache.value[suiteId]) {
    console.log('套件已缓存，跳过加载:', suiteId)
    return // 已缓存，不需要重新加载
  }
  if (loadingSuitePacks.value[suiteId]) {
    console.log('套件正在加载中，跳过重复加载:', suiteId)
    return // 正在加载中，避免重复加载
  }
  try {
    console.log('开始加载套件表情包:', suiteId)
    // 使用响应式方式更新加载状态
    loadingSuitePacks.value[suiteId] = true
    loadingSuitePacks.value = { ...loadingSuitePacks.value }
    const suitePacks = await api.emojiPack.getSuitePacks(suiteId)
    console.log('套件表情包加载成功（原始数据）:', suiteId, JSON.stringify(suitePacks, null, 2))
    // 详细打印每个表情包的数据结构
    suitePacks.forEach((pack, index) => {
      console.log(`表情包 ${index} 详细信息:`, {
        packId: pack.pack?.id,
        packName: pack.pack?.name,
        itemsType: typeof pack.items,
        itemsIsArray: Array.isArray(pack.items),
        itemsCount: pack.items?.length || 0,
        items: pack.items,
        itemsStringified: JSON.stringify(pack.items, null, 2)
      })
    })
    // 使用响应式方式更新缓存 - 直接修改对象属性以确保响应式更新
    suitePacksCache.value[suiteId] = suitePacks
    // 触发响应式更新 - 通过重新赋值整个对象
    suitePacksCache.value = { ...suitePacksCache.value }
    console.log('套件缓存已更新:', suitePacksCache.value)
    console.log('验证缓存中的套件数据:', suitePacksCache.value[suiteId])
  } catch (error) {
    console.error('加载套件表情包失败:', suiteId, error)
    suitePacksCache.value[suiteId] = []
    // 触发响应式更新
    suitePacksCache.value = { ...suitePacksCache.value }
  } finally {
    // 使用响应式方式更新加载状态
    loadingSuitePacks.value[suiteId] = false
    loadingSuitePacks.value = { ...loadingSuitePacks.value }
  }
}

// 加载用户表情包
const loadUserPacks = async () => {
  loadingPacks.value = true
  try {
    // 使用 list_user_packs API，它已经返回了包含 items 的数据
    const data = await api.emojiPack.getUserPacks()
    console.log('loadUserPacks: API 返回的原始数据:', data)
    userPacks.value = data.map((item) => ({
      ...item.pack,
      items: item.items || []
    }))
    console.log('loadUserPacks: 处理后的 userPacks:', userPacks.value)
    // 打印每个表情包的 items 信息
    userPacks.value.forEach((pack: EmojiPack, index: number) => {
      console.log(`表情包 ${index}: id=${pack.id}, name=${pack.name}, pack_type=${pack.pack_type}, items数量=${pack.items?.length || 0}`)
      if (pack.items && pack.items.length > 0) {
        console.log(`  表情项:`, pack.items.map((i: EmojiItem) => ({ id: i.id, name: i.name, image_url: i.image_url })))
      }
    })
    // 不清空套件缓存，保留已加载的套件数据
    // 只在需要时重新加载特定套件
    // suitePacksCache.value = {}
    // loadingSuitePacks.value = {}
    // 不预加载套件，改为按需加载（点击 tab 时再加载）
    // 这样可以避免预加载失败导致的问题，并且提升初始加载速度
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

// 监听 tab 切换，切换到套件 tab 时确保加载数据
watch(selectedTabIndex, (newIndex) => {
  const tab = tabs.value[newIndex]
  console.log('Tab 切换:', newIndex, tab)
  if (tab?.type === 'pack' && tab.pack) {
    // 切换到套件 tab 时，如果缓存中没有数据，主动加载
    const suiteId = tab.pack.id
    console.log('切换到套件 tab，suiteId:', suiteId, '缓存状态:', suitePacksCache.value[suiteId], '加载状态:', loadingSuitePacks.value[suiteId])
    if (!suitePacksCache.value[suiteId] && !loadingSuitePacks.value[suiteId]) {
      console.log('触发套件加载:', suiteId)
      loadSuitePacks(suiteId)
    }
  }
})

onMounted(() => {
  if (props.show) {
    loadUserPacks()
  }
})

// SVG 图标组件
const TabIcon = defineComponent({
  props: {
    type: {
      type: String,
      required: true
    }
  },
  setup(props) {
    return () => {
      const iconProps = {
        width: 20,
        height: 20,
        viewBox: '0 0 24 24',
        fill: 'none',
        stroke: 'currentColor',
        'stroke-width': '1.5',
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round' as const
      }

      switch (props.type) {
        case 'search':
          return h('svg', iconProps, [
            h('circle', { cx: '11', cy: '11', r: '8' }),
            h('path', { d: 'm21 21-4.35-4.35' })
          ])
        case 'emoji':
          return h('svg', iconProps, [
            h('circle', { cx: '12', cy: '12', r: '10' }),
            h('path', { d: 'M8 14s1.5 2 4 2 4-2 4-2' }),
            h('line', { x1: '9', y1: '9', x2: '9.01', y2: '9' }),
            h('line', { x1: '15', y1: '9', x2: '15.01', y2: '9' })
          ])
        case 'custom':
          return h('svg', iconProps, [
            h('path', { d: 'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z' })
          ])
        default:
          return null
      }
    }
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
@use '../styles/variables.scss' as *;
.emoji-picker {
  position: absolute;
  bottom: 100%;
  left: 0;
  margin-bottom: 8px;
  width: 420px;
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
  gap: 8px;
  padding: 8px;
  border-bottom: 1px solid #e5e5e5;
  flex-shrink: 0;
  overflow: hidden;
}

.emoji-tab {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  padding: 1px;
  width: 28px;
  height: 28px;
  border-radius: 5px;
  white-space: nowrap;
  transition: all 0.2s ease;
  font-size: 12px;
  flex-shrink: 0;
  color: $text-secondary;
  background-color: transparent;
  border: none;

  &:hover {
    background-color: rgba($primary-color, 0.08);
    color: $primary-color;
  }

  &.active {
    background-color: rgba($primary-color, 0.15);
    color: $primary-color;
    font-weight: 600;
  }

  .tab-icon {
    width: 20px;
    height: 20px;
    object-fit: contain;
    flex-shrink: 0;
  }

  .tab-icon svg {
    width: 20px;
    height: 20px;
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
}

.search-result-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px;
  border-radius: 8px;
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
  gap: 12px;
  width: 100%;
  box-sizing: border-box;

  &.emoji-grid-8 {
    grid-template-columns: repeat(8, 1fr);
    gap: 8px;
  }

  &.emoji-grid-6 {
    grid-template-columns: repeat(6, 1fr);
  }
}

.emoji-item {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  aspect-ratio: 1;
  border-radius: 6px;
  transition: background-color 0.2s;
  min-width: 0;
  overflow: hidden;
  width: 100%;

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
    object-fit: contain; // 保持原始宽高比，缩放以适应容器
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
