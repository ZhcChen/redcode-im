<template>
  <div class="contact-page">
    <div class="contact-header">
      <div class="header-left" :style="{ width: contactListWidth + 'px' }">
        <Popover ref="menuPopoverRef" placement="bottom" :offset="8" :content-offset-x="30" :content-offset-y="15" :arrow-offset-x="-30">
          <template #trigger>
            <img 
              src="@/assets/image/icon-menu.svg" 
              alt="菜单" 
              class="menu-icon"
            />
          </template>
          <template #content>
            <div class="menu-popup">
              <div class="popover-item" @click="handleAddContact">
                <img 
                  src="@/assets/image/icon-message.svg"
                  alt="添加联系人"
                  class="popover-icon"
                />
                <span class="popover-label">添加联系人</span>
              </div>
            </div>
          </template>
        </Popover>
        <SearchInput 
          v-model="searchQuery"
          placeholder="搜索联系人..."
          @search="handleSearch"
        />
      </div>
      <h2>{{ pageTitle }}</h2>
    </div>
    
    <div class="contact-content">
      <OverlayScrollbarsComponent
        class="contact-list"
        :style="{ width: contactListWidth + 'px' }"
        :options="{
          scrollbars: {
            visibility: 'visible',
            autoHide: 'leave',
            autoHideDelay: 0,
            autoHideSuspend: true,
            dragScroll: true,
            clickScroll: true
          }
        }"
      >
        <!-- 新的朋友列表 -->
        <div v-if="showFriendRequests" class="friend-requests-view">
          <!-- 好友申请页面头部 -->
          <div class="friend-requests-header">
            <div class="header-content">
              <!-- 新的朋友图标 -->
              <img src="@/assets/image/icon-new-friend.svg" alt="新的朋友" class="new-friend-icon" />
              
              <!-- 返回按钮区域 -->
              <div class="back-section" @click="handleBackToContacts">
                <img src="@/assets/image/icon-back.svg" alt="返回" class="back-icon" />
                <span class="back-text">返回联系人列表</span>
              </div>
            </div>
          </div>
          
          <!-- 好友申请列表 -->
          <div class="friend-requests-list">
            <!-- 只有在初始加载且没有缓存数据时才显示loading -->
            <div v-if="isLoadingFriendRequests && friendRequests.length === 0" class="loading-state">
              <div class="loading-text">正在获取好友申请...</div>
            </div>

            <!-- 空状态 -->
            <div v-else-if="!isLoadingFriendRequests && friendRequests.length === 0" class="empty-state">
              <div class="empty-text">暂无好友申请</div>
            </div>

            <!-- 好友申请列表 -->
            <div
              v-else
              v-for="request in friendRequests"
              :key="request.id"
              class="friend-request-item"
              @click="selectFriendRequest(request)"
            >
              <Avatar :src="request.avatar" :text="request.name" :size="48" />
              <div class="request-info">
                <div class="request-name-status">
                  <div class="request-name">{{ request.name }}</div>
                  <div
                    class="request-status"
                    :class="getRequestStatusClass(request.status)"
                  >
                    {{ request.status }}
                  </div>
                </div>
                <div class="request-message">{{ request.message || '请求添加您为好友' }}</div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 联系人主页面 -->
        <div v-else class="contacts-main-view">
          <!-- 固定项目 -->
          <div class="fixed-items">
            <div class="contact-item fixed-item" @click="handleNewFriends">
              <img src="@/assets/image/icon-new-friend.svg" alt="新的朋友" class="fixed-item-icon" />
              <div class="contact-info">
                <div class="contact-name-time">
                  <div class="contact-name">新的朋友</div>
                  <Badge :value="pendingFriendRequests" class="friend-request-badge" />
                </div>
              </div>
            </div>
            <div class="contact-item fixed-item" @click="handleGroups">
              <img src="@/assets/image/icon-group.svg" alt="群组" class="fixed-item-icon" />
              <div class="contact-info">
                <div class="contact-name-time">
                  <div class="contact-name">群组</div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- 联系人列表 -->
          <div class="alphabet-list">
            <!-- 加载状态 -->
            <div v-if="contactsLoading && contacts.length === 0" class="loading-state">
              <div class="loading-text">正在加载联系人...</div>
            </div>
            
            <!-- 错误状态 -->
            <div v-else-if="contactsError" class="error-state">
              <div class="error-text">{{ contactsError }}</div>
            </div>
            
            <!-- 空状态 -->
            <div v-else-if="contacts.length === 0 && !contactsLoading" class="empty-state">
              <div class="empty-text">暂无联系人</div>
            </div>
            
            <!-- 联系人分组列表 -->
            <div v-else v-for="(group, letter) in groupedContacts" :key="letter" class="alphabet-group">
              <div class="alphabet-header">{{ letter }}</div>
              <div class="contact-item" 
                   v-for="contact in group" 
                   :key="contact.id"
                   :class="{ 'selected': selectedContact && selectedContact.id === contact.id }"
                   @click="selectContact(contact)">
                <Avatar :src="contact.avatar" :text="contact.name" :size="48" />
                <div class="contact-info">
                  <div class="contact-name-time">
                    <div class="contact-name">{{ contact.name }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </OverlayScrollbarsComponent>

      <div class="resize-handle"
           @mousedown="startResize"
           @dblclick="resetWidth">
        <div class="resize-line"></div>
      </div>
      
      <!-- 好友申请用户详情 -->
      <div class="friend-request-detail" v-if="selectedFriendRequest">
        <div class="friend-request-profile">
          <div class="friend-profile-content">
            <!-- 头像 -->
            <div class="friend-avatar-section">
              <Avatar :src="selectedFriendRequest.avatar" :text="selectedFriendRequest.name" :size="100" />
            </div>
            
            <!-- 用户名 -->
            <div class="friend-name-section">
              <h4 class="friend-name">{{ selectedFriendRequest.name }}</h4>
            </div>
            
            <!-- 手机号 -->
            <div class="friend-phone-section" v-if="selectedFriendRequest.phone">
              <span class="phone-label">手机号：</span>
              <span class="phone-number">{{ selectedFriendRequest.phone }}</span>
            </div>
            
            <!-- 分割线 -->
            <div class="friend-divider"></div>
            
            <!-- 打招呼消息 - 只有对方发起的申请才显示 -->
            <div class="friend-greeting-section" v-if="selectedFriendRequest.message && !isMyFriendRequest(selectedFriendRequest)">
              <span class="greeting-label">打招呼：</span>
              <span class="greeting-message">{{ selectedFriendRequest.message }}</span>
            </div>
          </div>
          
          <!-- 操作按钮区域 - 只有对方发起的申请才显示 -->
          <div class="friend-action-section" v-if="!isMyFriendRequest(selectedFriendRequest)">
            <!-- 对方发起的申请 -->
            <div class="others-request-actions">
              <div v-if="selectedFriendRequest.status === '待验证'" class="others-request-pending">
                <button @click="handleRejectFriendRequest(selectedFriendRequest)" class="reject-btn">拒绝</button>
                <button @click="handleAcceptFriendRequest(selectedFriendRequest)" class="accept-btn">通过验证</button>
              </div>
              <div v-else-if="selectedFriendRequest.status === '已通过'" class="others-request-accepted">
                <p class="success-text">你已同意该好友申请</p>
                <button @click="startChatWithFriendRequest(selectedFriendRequest)" class="chat-btn">发起聊天</button>
              </div>
              <div v-else-if="selectedFriendRequest.status === '已拒绝'" class="others-request-rejected">
                <p class="error-text">你已拒绝该好友申请</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 联系人详情 -->
      <div class="contact-detail" v-else-if="selectedContact">
        <div class="contact-profile">
          <div class="contact-profile-content">
            <!-- 头像 -->
            <div class="contact-avatar-section">
              <Avatar :src="selectedContact.avatar" :text="selectedContact.name" :size="100" />
            </div>
            
            <!-- 用户名 -->
            <div class="contact-name-section">
              <h4 class="contact-name">{{ selectedContact.name }}</h4>
            </div>
          </div>
          
          <!-- 操作按钮区域 -->
          <div class="contact-action-section">
            <div class="contact-actions">
              <button @click="startChat(selectedContact)" class="chat-btn">发消息</button>
            </div>
          </div>
        </div>
      </div>
      
      <div class="empty-contact" v-else>
        <p v-if="showFriendRequests">选择一个好友申请查看详情</p>
        <p v-else>选择一个联系人查看详情</p>
      </div>
    </div>
    
    <!-- 添加联系人对话框 -->
    <Dialog 
      v-model="showAddDialog" 
      title="添加联系人" 
      @confirm="handleConfirmAddContact"
      @cancel="handleCancelAddContact"
      :confirm-text="isSearching ? '搜索中...' : '搜索'"
      :confirm-disabled="isSearching"
    >
      <div class="add-contact-content">
        <p class="add-contact-tip">请输入要搜索的用户账号</p>
        <DialogInput 
          v-model="addContactInput"
          placeholder="请输入手机号、用户名或聊天号..."
          :disabled="isSearching"
          @keyup.enter="triggerAddContactSearch"
        />
        
        <!-- 错误提示 -->
        <div v-if="searchError" class="search-error">
          {{ searchError }}
        </div>
        
        <!-- 搜索结果 -->
        <div v-if="searchResults.length > 0" class="search-results">
          <div class="search-results-header">
            <span>找到 {{ searchResults.length }} 个用户</span>
          </div>
          <div class="search-results-list">
            <div 
              v-for="user in searchResults" 
              :key="user.id"
              class="search-result-item"
              :class="{ 'disabled': isAddingFriend }"
              @click="isAddingFriend ? null : handleSelectUser(user)"
            >
              <Avatar 
                :src="user.avatar" 
                :text="user.realName || user.userName" 
                :size="40" 
              />
              <div class="user-info">
                <div class="user-name">{{ user.realName || user.userName }}</div>
                <div class="user-details">
                  <span class="mobile">{{ user.mobile }}</span>
                </div>
              </div>
              <div class="user-status">
                <span v-if="user.isFriend" class="friend-badge">已是好友</span>
                <span 
                  v-else-if="addingFriendId === user.id" 
                  class="adding-friend-btn"
                >
                  添加中...
                </span>
                <span v-else class="add-friend-btn">添加</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Dialog>

    <!-- 联系人详情弹窗 -->
    <div v-if="selectedContact" class="contact-modal" @click="closeModal">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3>联系人详情</h3>
          <button @click="closeModal" class="close-btn">×</button>
        </div>
        <div class="modal-body">
          <div class="profile-section">
            <Avatar :src="selectedContact.avatar" :text="selectedContact.name" :size="80" />
            <h4>{{ selectedContact.name }}</h4>
            <p class="contact-phone">{{ selectedContact.phone }}</p>
            <p class="contact-email">{{ selectedContact.email }}</p>
          </div>
          <div class="action-section">
            <button @click="startChat(selectedContact)" class="primary-btn">发起聊天</button>
            <button @click="makeCall(selectedContact)" class="secondary-btn">语音通话</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from 'vuex'
import { OverlayScrollbarsComponent } from 'overlayscrollbars-vue'
import 'overlayscrollbars/styles/overlayscrollbars.css'
import Avatar from '../components/Avatar.vue'
import SearchInput from '../components/SearchInput.vue'
import Popover from '../components/Popover.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import Badge from '../components/Badge.vue'
import { UserApi, type UserInfo } from '../api/user'
import { FriendApi } from '../api/friend'
import { toast } from '../utils/toast'
import { eventManager } from '../utils/eventManager'
import type { Contact } from '../store/index'
import type { FriendRequest } from '../store/index'

// Props: 接收账号ID（用于多实例页面架构）
interface Props {
  accountId?: string
}

const props = withDefaults(defineProps<Props>(), {
  accountId: undefined
})

const router = useRouter()
const store = useStore()
const searchQuery = ref('')
const currentFilter = ref('all')
const selectedContact = ref<Contact | null>(null)
// 加载状态
const isLoadingContacts = ref(false)
const isResizing = ref(false)
const startX = ref(0)
const startWidth = ref(0)
// 添加联系人对话框相关状态
const showAddDialog = ref(false)
const addContactInput = ref('')
const searchResults = ref<UserInfo[]>([])
const isSearching = ref(false)
const searchError = ref('')
const isAddingFriend = ref(false)
const addingFriendId = ref<string | null>(null)
// Popover 引用
const menuPopoverRef = ref()
// 新的朋友页面状态
const showFriendRequests = ref(false)
// 选中的好友申请用户详情
const selectedFriendRequest = ref<FriendRequest | null>(null)

// 最小和最大宽度限制
const minWidth = 300
const maxWidthVw = 70

// 使用 store 中的宽度状态
const contactListWidth = computed({
  get: () => store.getters.sidebarWidth,
  set: (value: number) => store.dispatch('setSidebarWidth', value)
})

// 使用 store 中的联系人数据
const contacts = computed(() => store.getters.contacts)
const contactsLoading = computed(() => store.getters.contactsLoading)
const contactsError = computed(() => store.getters.contactsError)

// 好友申请数据 - 使用store中的数据
const friendRequests = computed(() => store.getters.friendRequests)
const isLoadingFriendRequests = computed(() => store.getters.friendRequestsLoading)

// 添加本地初始化状态，避免重复加载
const isFriendRequestsInitialized = ref(false)

const filteredContacts = computed(() => {
  let result = contacts.value

  // 根据过滤器筛选
  if (currentFilter.value === 'online') {
    result = result.filter(contact => contact.isOnline)
  } else if (currentFilter.value === 'recent') {
    result = result.filter(contact => contact.isRecent)
  }

  // 根据搜索关键词筛选
  if (searchQuery.value) {
    result = result.filter(contact => 
      contact.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      contact.phone.includes(searchQuery.value) ||
      (contact.email && contact.email.toLowerCase().includes(searchQuery.value.toLowerCase()))
    )
  }

  return result
})

// 使用 store 中的分组数据
const groupedContacts = computed(() => {
  // 如果有搜索关键词，使用本地筛选的结果
  if (searchQuery.value) {
    const groups: Record<string, Contact[]> = {}
    
    filteredContacts.value.forEach(contact => {
      const firstChar = contact.name[0].toUpperCase()
      const key = /[A-Z]/.test(firstChar) ? firstChar : '#'
      
      if (!groups[key]) {
        groups[key] = []
      }
      groups[key].push(contact)
    })
    
    // 排序
    Object.keys(groups).forEach(key => {
      groups[key].sort((a, b) => a.name.localeCompare(b.name))
    })
    
    return groups
  }
  
  // 否则使用 store 中的分组数据
  return store.getters.groupedContacts
})

const onlineCount = computed(() => {
  return store.getters.onlineContactsCount
})

// 从 store 获取待处理的好友申请数量
const pendingFriendRequests = computed(() => {
  return store.getters.pendingFriendRequests
})

const getRequestStatusClass = (status: string) => {
  if (status === '待验证') return 'status-pending'
  if (status === '已通过') return 'status-approved'
  if (status === '已拒绝') return 'status-rejected'
  return ''
}

// 动态页面标题
const pageTitle = computed(() => {
  if (showFriendRequests.value) {
    // 在新的朋友页面
    if (selectedFriendRequest.value) {
      // 选中了具体的好友申请
      return '新的朋友申请'
    } else {
      // 在新的朋友列表页面
      return '新的朋友'
    }
  } else {
    // 在联系人主页面
    return '联系人'
  }
})

const setFilter = (filter: string) => {
  currentFilter.value = filter
}

// 加载联系人列表
const loadContactsList = async (forceRefresh = false) => {
  try {
    isLoadingContacts.value = true

    // 如果不强制刷新且store中有数据，直接返回
    if (!forceRefresh && contacts.value.length > 0) {
      return
    }

    // 调用store的loadContacts action，传入比对逻辑参数
    await store.dispatch('loadContacts', {
      forceRefresh,
      compareWithStore: true // 启用与store的数据比对
    })
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '加载联系人列表失败';
    toast.error(errorMessage)
  } finally {
    isLoadingContacts.value = false
  }
}

const selectContact = (contact: Contact) => {
  selectedContact.value = contact
  selectedFriendRequest.value = null // 清除选中的好友申请
}

const closeModal = () => {
  selectedContact.value = null
}

const startChat = (contact: Contact) => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    // 更新账号的路由状态到聊天页面，并传递联系人信息
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/chat',
        name: 'Chat',
        params: {},
        query: {
          contactId: contact.id.toString(),
          contactName: contact.name
        }
      }
    })
  } else {
    // 否则使用全局路由（向后兼容）
    router.push({ 
      path: '/home/chat', 
      query: { 
        contactId: contact.id.toString(),
        contactName: contact.name
      } 
    })
  }
  
  // 清除选中状态
  selectedContact.value = null
}

const viewProfile = (contact: Contact) => {
  selectContact(contact)
}

const makeCall = (contact: Contact) => {
  // 发起语音通话逻辑
  selectedContact.value = null
}

const handleSearch = async (value: string) => {
  searchQuery.value = value
  
  // 如果有搜索关键词，触发 API 搜索
  if (value.trim()) {
    try {
      await store.dispatch('searchContacts', value.trim())
    } catch (error: any) {
      toast.error(error.message || '搜索联系人失败')
    }
  } else {
    // 如果清空搜索，重新加载完整列表
    await loadContactsList()
  }
}

const handleAddContact = () => {
  // 关闭 Popover 弹窗
  if (menuPopoverRef.value) {
    menuPopoverRef.value.hide()
  }
  // 打开添加联系人对话框
  showAddDialog.value = true
  addContactInput.value = ''
}

const handleNewFriends = async () => {

  // 清除选中的联系人
  selectedContact.value = null
  selectedFriendRequest.value = null

  // 先显示好友申请页面
  showFriendRequests.value = true

  // 延迟一下再加载数据，确保UI已经切换
  await new Promise(resolve => setTimeout(resolve, 50))

  // 优先从store加载好友申请数据
  await loadFriendRequests(false) // 从store加载

  // 只有在初始化成功后才启动后台刷新，避免重复请求
  if (isFriendRequestsInitialized.value) {
    // 后台异步刷新数据，避免界面闪烁
    setTimeout(async () => {
      try {
        await loadFriendRequests(true) // 强制刷新API数据
      } catch (error: any) {
        // 即使失败也不影响用户体验，用户可以看到store中的数据
      }
    }, 500) // 500ms 后开始后台刷新
  }
}

const handleBackToContacts = () => {
  showFriendRequests.value = false
  selectedFriendRequest.value = null // 清除选中的好友申请
}

// 选择好友申请
const selectFriendRequest = (request: FriendRequest) => {
  selectedFriendRequest.value = request
  selectedContact.value = null // 清除选中的联系人
}

// 判断是否为我发起的好友申请
const isMyFriendRequest = (request: FriendRequest): boolean => {
  const currentUser = store.state.user
  if (!currentUser?.id) return false

  // 如果 fromUserId 等于当前用户ID，说明是我发起的申请
  return request.fromUserId === currentUser.id.toString()
}

// 加载好友申请列表 - 优化为使用store持久化
const loadFriendRequests = async (forceRefresh = false) => {
  try {

    // 如果已经初始化过且不强制刷新，直接返回
    if (isFriendRequestsInitialized.value && !forceRefresh) {
      return
    }

    // 如果不强制刷新且store中有数据，优先从store加载
    if (!forceRefresh && friendRequests.value.length > 0) {
      isFriendRequestsInitialized.value = true
      return
    }

    // 调用store的loadFriendRequests action，传入比对逻辑参数
    await store.dispatch('loadFriendRequests', {
      forceRefresh,
      compareWithStore: true // 启用与store的数据比对
    })

    isFriendRequestsInitialized.value = true
  } catch (error: any) {
    // 静默处理错误，不显示toast
  }
}

// 更新待处理好友申请数量
const updatePendingFriendRequestsCount = async () => {
  try {
    const response = await FriendApi.getPendingFriendRequestCount()
    if (response.success && typeof response.data === 'number') {
      store.commit('SET_PENDING_FRIEND_REQUESTS', response.data)
    }
  } catch (error: any) {
  }
}

const handleGroups = () => {
  // 这里可以添加查看群组列表的逻辑
}

// 处理添加联系人对话框确定按钮
const handleConfirmAddContact = async () => {
  if (isSearching.value) {
    return
  }
  const keyword = addContactInput.value.trim()
  if (!keyword) {
    searchError.value = '请输入要搜索的账号'
    return
  }
  
  // 重置状态
  isSearching.value = true
  searchError.value = ''
  searchResults.value = []
  
  try {
    // 调用搜索用户API - 使用与 bear-chat-uniapp 相同的参数格式
    const response = await UserApi.searchUser({
      keyWord: keyword
    })
    
    if (response.success) {
      if (response.data && response.data.length > 0) {
        // 搜索成功，有结果
        searchResults.value = response.data
      } else {
        // 搜索成功但无结果，或者 data 为 null
        searchError.value = response.message || '该用户不存在!'
        searchResults.value = []
      }
    } else {
      // 搜索失败
      searchError.value = response.message || '搜索失败，请稍后重试'
      searchResults.value = []
    }
  } catch (error: any) {
    searchError.value = error.message || '网络错误，请稍后重试'
    searchResults.value = []
  } finally {
    isSearching.value = false
  }
}

const triggerAddContactSearch = () => {
  if (isSearching.value) return
  handleConfirmAddContact()
}

// 处理添加联系人对话框取消按钮
const handleCancelAddContact = () => {
  closeAddContactDialog()
}

// 处理选择用户
const handleSelectUser = async (user: UserInfo) => {

  if (user.isFriend) {
    // 如果已经是好友，跳转到聊天
    try {
      const response = await FriendApi.ensureChat({
        friendId: user.id,
      })

      if (response.success && response.data) {
        // 跳转到聊天页面
        await router.push({
          name: 'Chat',
          params: {
            groupId: response.data.roomId,
          },
          query: {
            // 可以添加额外的查询参数
          },
        })
        closeAddContactDialog()
      } else {
        throw new Error(response.message || '获取聊天房间失败')
      }
    } catch (error: any) {
      toast.error('跳转失败: ' + (error.message || '网络错误'))
    }
    return
  }

  // 检查是否添加自己
  const currentUser = store.state.user
  if (currentUser.mobile === user.mobile) {
    searchError.value = '不能添加自己为好友'
    return
  }

  // 添加好友
  isAddingFriend.value = true
  addingFriendId.value = user.id
  try {
    const response = await FriendApi.addFriend({
      friendId: user.id,
      description: `我是${currentUser.nickname || currentUser.username}`
    })

    if (response.success) {
      // 显示成功提示
      toast.success('好友添加邀请已发送')
      searchError.value = ''
      
      // 延迟关闭对话框，让用户看到成功状态
      setTimeout(() => {
        closeAddContactDialog()
      }, 1500)
    } else {
      searchError.value = response.message || '发送好友申请失败'
    }
  } catch (error: any) {
    searchError.value = error.message || '网络错误，请稍后重试'
  } finally {
    isAddingFriend.value = false
    addingFriendId.value = null
  }
}

// 关闭添加联系人对话框
const closeAddContactDialog = () => {
  showAddDialog.value = false
  addContactInput.value = ''
  searchResults.value = []
  searchError.value = ''
  isSearching.value = false
  isAddingFriend.value = false
  addingFriendId.value = null
}

// 接受好友申请
const handleAcceptFriendRequest = async (request: FriendRequest) => {
  try {

    // 调用处理好友申请API，status: 1 表示同意
    // 使用 fromUserId 作为 applyUserId，因为这是申请人的用户ID
    const response = await FriendApi.handleFriendRequest({
      requestId: request.id,
      action: 'accept'
    })

    if (response.success) {
      toast.success('已接受好友申请')
      // 更新store中的好友申请状态
      const updatedRequest = { ...request, status: '已通过' as const }
      store.dispatch('updateFriendRequest', updatedRequest)
      selectedFriendRequest.value = updatedRequest
      // 重新加载好友申请列表，使用后台同步模式
      setTimeout(async () => {
        await loadFriendRequests(true)
      }, 300)
      // 更新待处理数量
      await updatePendingFriendRequestsCount()
    } else {
      toast.error(response.message || '接受好友申请失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '接受好友申请失败';
    toast.error(errorMessage)
  }
}

// 拒绝好友申请
const handleRejectFriendRequest = async (request: FriendRequest) => {
  try {

    // 调用处理好友申请API，status: 2 表示拒绝
    // 使用 fromUserId 作为 applyUserId，因为这是申请人的用户ID
    const response = await FriendApi.handleFriendRequest({
      requestId: request.id,
      action: 'decline'
    })

    if (response.success) {
      toast.success('已拒绝好友申请')
      // 更新store中的好友申请状态
      const updatedRequest = { ...request, status: '已拒绝' as const }
      store.dispatch('updateFriendRequest', updatedRequest)
      selectedFriendRequest.value = updatedRequest
      // 重新加载好友申请列表，使用后台同步模式
      setTimeout(async () => {
        await loadFriendRequests(true)
      }, 300)
      // 更新待处理数量
      await updatePendingFriendRequestsCount()
    } else {
      toast.error(response.message || '拒绝好友申请失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '拒绝好友申请失败';
    toast.error(errorMessage)
  }
}

// 与好友申请用户发起聊天
const startChatWithFriendRequest = (request: FriendRequest) => {
  // 如果有多账号架构，更新账号的路由状态
  if (props.accountId) {
    // 更新账号的路由状态到聊天页面，并传递用户信息
    store.dispatch('accounts/saveAccountRouteState', {
      accountId: props.accountId,
      routeState: {
        path: '/home/chat',
        name: 'Chat',
        params: {},
        query: {
          contactId: request.fromUserId || request.id,
          contactName: request.name
        }
      }
    })
  } else {
    // 否则使用全局路由（向后兼容）
    router.push({ 
      path: '/home/chat', 
      query: { 
        contactId: request.fromUserId || request.id,
        contactName: request.name
      } 
    })
  }
  
  // 清除选中状态
  selectedFriendRequest.value = null
}

// 撤销我发起的好友申请
const cancelMyFriendRequest = async (request: FriendRequest) => {
  try {
    const confirmed = confirm(`确定要撤销向 ${request.addressee.nickname || request.addressee.username} 发送的好友申请吗？`)
    if (!confirmed) return

    const response = await FriendApi.cancelFriendRequest({
      requestId: request.id,
    })

    if (response.success) {
      toast.success('已撤销好友申请')
      // 重新加载好友申请列表
      await loadFriendRequests()
    } else {
      throw new Error(response.message || '撤销失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('撤销失败: ' + errorMessage)
  }
}

// 拖拽调整宽度相关函数
const getMaxWidth = () => {
  return window.innerWidth * (maxWidthVw / 100)
}

const startResize = (e: MouseEvent) => {
  isResizing.value = true
  startX.value = e.clientX
  startWidth.value = contactListWidth.value
  
  document.addEventListener('mousemove', handleResize)
  document.addEventListener('mouseup', stopResize)
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

const handleResize = (e: MouseEvent) => {
  if (!isResizing.value) return
  
  const deltaX = e.clientX - startX.value
  const newWidth = startWidth.value + deltaX
  const maxWidth = getMaxWidth()
  
  contactListWidth.value = Math.max(minWidth, Math.min(newWidth, maxWidth))
}

const stopResize = () => {
  isResizing.value = false
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}

const resetWidth = () => {
  contactListWidth.value = 300
}

// 监听窗口大小变化，确保宽度不超过限制
const handleWindowResize = () => {
  const maxWidth = getMaxWidth()
  if (contactListWidth.value > maxWidth) {
    contactListWidth.value = maxWidth
  }
}

// 为每个账号缓存页面状态
interface ContactAccountState {
  searchQuery: string
  currentFilter: string
}

const accountStates = new Map<string, ContactAccountState>()

// 保存当前账号的状态
const saveCurrentAccountState = (accountId: string) => {
  accountStates.set(accountId, {
    searchQuery: searchQuery.value,
    currentFilter: currentFilter.value
  })
}

// 恢复指定账号的状态
const restoreAccountState = (accountId: string) => {
  const state = accountStates.get(accountId)
  if (state) {
    searchQuery.value = state.searchQuery
    currentFilter.value = state.currentFilter
  } else {
    searchQuery.value = ''
    currentFilter.value = 'all'
  }
  
  // 始终重置对话框状态（不需要保留）
  showAddDialog.value = false
  addContactInput.value = ''
  showFriendRequests.value = false
  isSearching.value = false
  isAddingFriend.value = false
  searchError.value = ''
  isFriendRequestsInitialized.value = false
}

// 监听账号切换，保存/恢复状态
watch(
  () => store.state.accounts?.currentAccountId,
  (newAccountId, oldAccountId) => {
    if (newAccountId && oldAccountId && newAccountId !== oldAccountId) {
      
      // 保存旧账号的状态
      saveCurrentAccountState(oldAccountId)
      
      // 恢复新账号的状态
      restoreAccountState(newAccountId)
      
    }
  }
)

onMounted(async () => {
  // 使用事件管理器添加监听器
  eventManager.addWindowListener('resize', handleWindowResize)

  // 等待用户登录状态完全稳定后再发起API请求，避免401错误
  const checkAndLoadData = async () => {

    // 检查用户是否已完全登录（包括用户信息）
    if (store.getters.isLoggedIn && 
        store.getters.token && 
        store.getters.currentUser?.id) {
      try {
        
        // 加载好友申请数量
        store.dispatch('updatePendingFriendRequests')

        // 加载联系人列表 - 优先从 store 加载，然后在后台刷新
        await loadContactsList(false) // 从 store 加载

        // 后台异步刷新数据，避免界面闪烁
        setTimeout(async () => {
          try {
            await loadContactsList(true) // 强制刷新API数据
          } catch (error: any) {
            // 即使失败也不影响用户体验，用户可以看到store中的数据
          }
        }, 500) // 500ms 后开始后台刷新
      } catch (error: any) {
        // 如果是认证错误，不要重试，让系统自动处理登出
        if (error.message && error.message.includes('认证')) {
          return;
        }
      }
    } else {
      // 如果状态不完整，再等待一段时间重试
      setTimeout(checkAndLoadData, 300);
    }
  };

  // 初始延迟更长，确保登录流程完全完成，避免401错误导致自动登出
  setTimeout(checkAndLoadData, 1500); // 增加到1.5秒
})

onUnmounted(() => {
  // 重置初始化状态
  isFriendRequestsInitialized.value = false

  // 事件管理器会自动清理，但为了保险起见，手动清理
  window.removeEventListener('resize', handleWindowResize)
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)
})
</script>

<style lang="scss" scoped>
// Variables are now globally imported via vite.config.ts

.contact-page {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.contact-header {
  padding: 16px 20px 16px 0; // 上 右 下 左，左侧设为0
  display: flex;
  align-items: center;
  height: 76px;
  box-sizing: border-box;
  flex-shrink: 0;
  
  .header-left {
    min-width: 300px;
    max-width: 70vw;
    display: flex;
    align-items: center;
    gap: 16px;
    margin-right: 20px;
    padding-left: 20px; // 恢复左侧内边距
    padding-right: 20px;
    box-sizing: border-box;
    
    .menu-icon {
      width: 24px;
      height: 24px;
      flex-shrink: 0;
      cursor: pointer;
      transition: opacity 0.2s;
      
      &:hover {
        opacity: 0.7;
      }
    }
    
    // 搜索组件占据剩余空间
    :deep(.search-input) {
      flex: 1;
    }
  }
  
  h2 {
    margin: 0;
    color: #262626;
    flex: 1;
  }
}

.contact-content {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.contact-list {
  min-width: 300px;
  max-width: 70vw;
  flex-shrink: 0;
}


.resize-handle {
  width: 2px;
  background-color: transparent;
  cursor: col-resize;
  position: relative;
  flex-shrink: 0;
  
  &:hover {
    background-color: rgba($primary-color, 0.1);
    
    .resize-line {
      background-color: $primary-color;
    }
  }
  
  &:active {
    background-color: rgba($primary-color, 0.15);
    
    .resize-line {
      background-color: $primary-dark;
    }
  }
}

.resize-line {
  width: 1px;
  height: 100%;
  background-color: #f0f0f0;
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  transition: background-color 0.2s;
}

.alphabet-group {
  margin-bottom: 0;
}

.alphabet-header {
  height: 24px;
  background-color: $bg-chat;
  display: flex;
  align-items: center;
  padding-left: 16px;
  font-size: 12px;
  font-weight: 500;
  color: #8c8c8c;
  position: sticky;
  top: 0;
  z-index: 1;
}

.contact-item {
  display: flex;
  align-items: center;
  height: 72px;
  padding: 0 16px;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #f0f0f0;
  
  &:hover {
    background-color: #f5f5f5;
  }
  
  &.selected {
    background-color: #F5F5F5;
  }
  
  &:last-child {
    border-bottom: none;
  }
  
  &.fixed-item {
    .contact-info {
      .contact-name-time {
        margin-bottom: 0;
        
        .contact-name {
          margin-bottom: 0;
        }
      }
    }
  }
  
  .contact-info {
    flex: 1;
    margin-left: 12px;
    min-width: 0;
    display: flex;
    flex-direction: column;
    justify-content: center;
    
    .contact-name-time {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
      
      .contact-name {
        font-weight: 500;
        font-size: 16px;
        color: $chat-name-color;
        line-height: 1.2;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        flex: 1;
        margin-right: 8px;
      }
      
      .contact-time {
        font-size: 12px;
        color: $chat-message-color;
        white-space: nowrap;
        flex-shrink: 0;
      }
      
      // 好友申请 Badge 的间距
      .friend-request-badge {
        margin-left: 8px;
        flex-shrink: 0;
      }
    }
  }
}

.fixed-item-icon {
  width: 48px;
  height: 48px;
  flex-shrink: 0;
}

.contact-detail, .friend-request-detail {
  flex: 1;
  display: flex;
  flex-direction: column;
  background-color: $bg-chat;
}

.contact-profile {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 32px;
}

.contact-profile-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 100%;
  max-width: 400px;
}

// 联系人头像区域
.contact-avatar-section {
  margin-bottom: 24px;
}

// 联系人用户名区域
.contact-name-section {
  margin-bottom: 40px;
  
  .contact-name {
    margin: 0;
    font-size: 22px;
    font-weight: bold;
    color: #2C2D3A;
    text-align: center;
  }
}

// 联系人操作按钮区域
.contact-action-section {
  width: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
}

// 联系人操作按钮样式
.contact-actions {
  display: flex;
  flex-direction: column;
  align-items: center;
  
  .chat-btn {
    height: 44px;
    width: 160px;
    border-radius: 10px;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s ease;
    border: none;
    background-color: $primary-color;
    color: white;
    
    &:hover {
      background-color: $primary-dark;
    }
  }
}

.empty-contact {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
}

.menu-popup {
  .popover-item {
    display: flex;
    align-items: center;
    padding: 12px 16px;
    cursor: pointer;
    transition: background-color 0.2s ease;
    
    &:hover {
      background-color: #f5f5f5;
    }
    
    .popover-icon {
      width: 24px;
      height: 24px;
      margin-right: 8px;
      flex-shrink: 0;
    }
    
    .popover-label {
      font-size: 14px;
      color: #707991;
      white-space: nowrap;
    }
  }
}

// 添加联系人对话框样式
.add-contact-content {
  padding: 16px 8px; // 增加左右内边距，减少视觉拥挤感
  
  .add-contact-tip {
    margin: 0 0 16px 0;
    font-size: 14px;
    color: #666;
    text-align: left;
  }
  
  // 针对 DialogInput 的特殊样式调整
  :deep(.dialog-input) {
    width: 100%; // 恢复全宽
    border-radius: 22px; // 保持与 DialogInput 组件一致的圆角
    padding: 0 20px; // 增加内边距，让文字不会太靠近边缘
    font-size: 14px; // 稍微增大字体
    
    &::placeholder {
      font-size: 14px;
    }
  }
  
  // 错误提示样式
  .search-error {
    margin-top: 12px;
    padding: 8px 12px;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    color: #dc2626;
    font-size: 14px;
  }
  
  // 搜索结果样式
  .search-results {
    margin-top: 16px;
    
    .search-results-header {
      padding: 8px 0;
      border-bottom: 1px solid #f0f0f0;
      font-size: 12px;
      color: #8c8c8c;
      font-weight: 500;
    }
    
    .search-results-list {
      max-height: 300px;
      overflow-y: auto;
    }
    
    .search-result-item {
      display: flex;
      align-items: center;
      padding: 12px 0;
      cursor: pointer;
      transition: background-color 0.2s ease;
      border-bottom: 1px solid #f5f5f5;
      
      &:hover:not(.disabled) {
        background-color: #f9f9f9;
      }
      
      &:last-child {
        border-bottom: none;
      }
      
      &.disabled {
        opacity: 0.6;
        cursor: not-allowed;
      }
      
      .user-info {
        flex: 1;
        margin-left: 12px;
        min-width: 0;
        
        .user-name {
          font-size: 16px;
          font-weight: 500;
          color: #262626;
          margin-bottom: 4px;
        }
        
        .user-details {
          .mobile {
            font-size: 12px;
            color: #8c8c8c;
          }
        }
      }
      
      .user-status {
        .friend-badge {
          padding: 4px 8px;
          background-color: #e6f7ff;
          color: #1890ff;
          font-size: 12px;
          border-radius: 12px;
        }
        
        .add-friend-btn {
          padding: 6px 12px;
          background-color: $primary-color;
          color: white;
          font-size: 12px;
          border-radius: 16px;
          cursor: pointer;
          transition: background-color 0.2s ease;
          
          &:hover {
            background-color: $primary-dark;
          }
        }
        
        .adding-friend-btn {
          padding: 6px 12px;
          background-color: #d9d9d9;
          color: #999999;
          font-size: 12px;
          border-radius: 16px;
          cursor: not-allowed;
        }
      }
    }
  }
}

// 保留弹窗样式用于兼容性
.contact-modal {
  display: none;
}

// 新的朋友页面样式
.friend-requests-view {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.friend-requests-header {
  height: 72px; // 与原来的 contact-item 高度保持一致
  padding: 0 16px; // 使用与 contact-item 相同的左右内边距
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  align-items: center; // 垂直居中
  
  .header-content {
    display: flex;
    align-items: center;
    width: 100%;
    
    .new-friend-icon {
      width: 48px;
      height: 48px;
      flex-shrink: 0;
    }
    
    .back-section {
      display: flex;
      align-items: center;
      cursor: pointer;
      margin-left: 16px; // 新的朋友图标右侧间距16px
      transition: opacity 0.2s ease;
      
      &:hover {
        opacity: 0.7;
      }
      
      .back-icon {
        width: 24px;
        height: 24px;
        flex-shrink: 0;
      }
      
      .back-text {
        margin-left: 8px; // 返回图标右侧间距8px
        font-size: 16px;
        color: $chat-name-color; // 使用全局定义的 #011627 颜色
        white-space: nowrap;
      }
    }
  }
}

.friend-requests-list {
  flex: 1;
  overflow-y: auto;
}

.friend-request-item {
  display: flex;
  align-items: center;
  height: 72px;
  padding: 0 16px;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #f0f0f0;
  
  &:hover {
    background-color: #f5f5f5;
  }
  
  &:last-child {
    border-bottom: none;
  }
  
  .request-info {
    flex: 1;
    margin-left: 12px;
    min-width: 0;
    display: flex;
    flex-direction: column;
    justify-content: center;
    
    .request-name-status {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px; // 与消息的上下间距
      
      .request-name {
        font-weight: bold; // 文字加粗
        font-size: 16px;
        line-height: 20px; // 行高 20px
        color: #011627; // 颜色 #011627
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        flex: 1;
        margin-right: 8px;
      }
      
      .request-status {
        font-size: 12px;
        color: $chat-message-color; // 使用全局定义的 #707991 颜色
        white-space: nowrap;
        flex-shrink: 0;
        font-weight: 500;

        &.status-pending {
          color: $primary-color;
        }

        &.status-approved {
          color: #2ebd85;
        }

        &.status-rejected {
          color: #ff5d52;
        }
      }
    }
    
    .request-message {
      font-size: 14px; // 文字 14px
      line-height: 18px; // 行高 18px
      color: #707991; // 颜色 #707991
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
  }
}

// 加载、空状态和错误状态样式
.loading-state, .empty-state, .error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 200px;
  gap: 12px;
  padding: 20px;
  
  .loading-text, .empty-text, .error-text {
    color: #8c8c8c;
    font-size: 14px;
    text-align: center;
  }
  
  .error-text {
    color: #ff4d4f;
  }
  
  .retry-button {
    padding: 8px 16px;
    background-color: $primary-color;
    color: white;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.2s ease;
    border: none;
    
    &:hover {
      background-color: $primary-dark;
    }
    
    &:active {
      background-color: $primary-dark;
      transform: translateY(1px);
    }
  }
}

// 好友申请详情特殊样式
.friend-request-detail {
  .friend-request-profile {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 32px;
  }
  
  .friend-profile-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
    max-width: 400px;
  }
  
  // 头像区域
  .friend-avatar-section {
    margin-bottom: 24px;
  }
  
  // 用户名区域
  .friend-name-section {
    margin-bottom: 16px;
    
    .friend-name {
      margin: 0;
      font-size: 22px;
      font-weight: bold;
      color: #2C2D3A;
      text-align: center;
    }
  }
  
  // 手机号区域
  .friend-phone-section {
    margin-bottom: 24px;
    text-align: center;
    
    .phone-label {
      font-size: 14px;
      color: #686A8A;
    }
    
    .phone-number {
      font-size: 14px;
      color: #2C2D3A;
    }
  }
  
  // 分割线
  .friend-divider {
    width: 300px;
    height: 1px;
    background-color: #E5E5E5;
    margin-bottom: 24px;
  }
  
  // 打招呼消息区域
  .friend-greeting-section {
    margin-bottom: 40px;
    text-align: center;
    
    .greeting-label {
      font-size: 14px;
      color: #707991;
    }
    
    .greeting-message {
      font-size: 14px;
      color: #000000;
    }
  }
  
  // 操作按钮区域
  .friend-action-section {
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  
  
  // 对方发起的申请按钮样式
  .others-request-actions {
    display: flex;
    flex-direction: column;
    align-items: center;
    
    .success-text {
      color: #2ebd85;
      font-size: 14px;
      margin: 0 0 20px 0;
      font-weight: 500;
      text-align: center;
    }
    
    .error-text {
      color: #ff5d52;
      font-size: 14px;
      margin: 0;
      font-weight: 500;
      text-align: center;
    }
    
    .others-request-pending {
      display: flex;
      gap: 24px;
      align-items: center;
      justify-content: center;
    }
    
    .reject-btn, .accept-btn, .chat-btn {
      height: 44px;
      width: 160px;
      border-radius: 10px;
      font-size: 14px;
      cursor: pointer;
      transition: all 0.2s ease;
      border: none;
    }
    
    .reject-btn {
      background-color: transparent;
      border: 1px solid $primary-color;
      color: $primary-color;
      
      &:hover {
        background-color: rgba($primary-color, 0.1);
      }
    }
    
    .accept-btn, .chat-btn {
      background-color: $primary-color;
      color: white;

      &:hover {
        background-color: $primary-dark;
      }
    }
  }
}
</style>

<!-- 非 scoped 样式块：OverlayScrollbars 自定义样式 -->
<style lang="scss">
// OverlayScrollbars 自定义主题样式 - 联系人列表
.contact-list {
  height: 100%;

  .os-viewport {
    overscroll-behavior: contain;
  }

  .os-scrollbar {
    --os-size: 12px;
    --os-padding-perpendicular: 2px;
    --os-padding-axis: 2px;
    --os-track-border-radius: 10px;
    --os-track-bg: transparent;
    --os-track-bg-hover: transparent;
    --os-track-bg-active: transparent;
    --os-handle-border-radius: 10px;
    --os-handle-bg: rgba(0, 0, 0, 0.3);
    --os-handle-bg-hover: rgba(0, 0, 0, 0.3);
    --os-handle-bg-active: rgba(0, 0, 0, 0.3);
    --os-handle-min-size: 40px;
    --os-handle-max-size: none;
    --os-handle-perpendicular-size: 60%;
    --os-handle-perpendicular-size-hover: 60%;
    --os-handle-perpendicular-size-active: 60%;
    --os-handle-interactive-area-offset: 4px;
  }

  .os-scrollbar-hidden {
    opacity: 0;
    transition: opacity 0.1s ease;
  }

  .os-scrollbar-visible {
    opacity: 1;
    transition: opacity 0.1s ease;
  }

  .os-scrollbar-vertical {
    right: 4px;
    top: 4px;
    bottom: 4px;
    width: 12px !important;

    .os-scrollbar-track {
      width: 12px !important;
    }

    .os-scrollbar-handle {
      width: 8px !important;
      min-height: 40px !important;
      transition: none !important;

      &:hover {
        width: 8px !important;
      }

      &:active {
        width: 8px !important;
      }
    }
  }

  .os-scrollbar-track {
    background: transparent !important;
    border-radius: 6px !important;

    &:hover {
      background: transparent !important;
    }

    &:active {
      background: transparent !important;
    }
  }

  .os-scrollbar-handle {
    background: rgba(0, 0, 0, 0.3) !important;
    border-radius: 10px !important;
    border: none !important;
    box-shadow: none !important;

    &:hover {
      background: rgba(0, 0, 0, 0.3) !important;
    }

    &:active {
      background: rgba(0, 0, 0, 0.3) !important;
    }
  }

  .os-scrollbar-horizontal {
    display: none !important;
  }
}

// 暗色主题支持 - 联系人列表
[data-theme="dark"] .contact-list {
  .os-scrollbar {
    --os-track-bg: transparent;
    --os-track-bg-hover: transparent;
    --os-track-bg-active: transparent;
    --os-handle-bg: rgba(255, 255, 255, 0.3);
    --os-handle-bg-hover: rgba(255, 255, 255, 0.3);
    --os-handle-bg-active: rgba(255, 255, 255, 0.3);
  }

  .os-scrollbar-track {
    background: transparent !important;

    &:hover {
      background: transparent !important;
    }
  }

  .os-scrollbar-handle {
    background: rgba(255, 255, 255, 0.3) !important;

    &:hover {
      background: rgba(255, 255, 255, 0.3) !important;
    }

    &:active {
      background: rgba(255, 255, 255, 0.3) !important;
    }
  }
}
</style>
