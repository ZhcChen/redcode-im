// @ts-nocheck
import { createStore } from 'vuex'
import type { AccountInfo } from './modules/accounts'
import type { Message as DomainMessage, AppVersionInfo } from '@/types/models'
import { UserApi, VersionApi, SettingsApi, apiConfig } from '@/api'
import favoriteAvatar from '@/assets/image/favorite-avatar.svg'
import { loadCache, saveCache, CACHE_KEYS } from '../utils/cache'
import accountsModule from './modules/accounts'
import {
    didEnterRelayOnlyMode,
    DEFAULT_MESSAGE_RUNTIME,
    resolveGeneralSettingsPayload,
    sanitizeChatSummaryForRuntime,
    sanitizeChatSummariesForRuntime,
    serializeGeneralSettingsPayload,
    type GeneralSettingsPayload,
    type MessageRuntimeSettings,
} from '@/services/messageRuntime'

// 辅助函数：格式化最后在线时间
function formatLastSeen(timeStr: string): string {
    if (!timeStr) return '未知'

    const now = new Date()
    const time = new Date(timeStr)

    // 检查时间是否有效
    if (isNaN(time.getTime())) return '未知'

    const diffMs = now.getTime() - time.getTime()
    const diffMinutes = Math.floor(diffMs / (1000 * 60))
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
    const diffDays = Math.floor(diffHours / 24)

    if (diffMinutes < 1) {
        return '刚刚'
    } else if (diffMinutes < 60) {
        return `${diffMinutes}分钟前`
    } else if (diffHours < 24) {
        return `${diffHours}小时前`
    } else if (diffDays === 1) {
        return '昨天'
    } else if (diffDays < 7) {
        return `${diffDays}天前`
    } else if (diffDays < 30) {
        return `${Math.floor(diffDays / 7)}周前`
    } else {
        return time.toLocaleDateString()
    }
}

// 辅助函数：判断是否为最近联系人（7天内添加的好友）
function isRecentContact(createTime: string): boolean {
    if (!createTime) return false

    const now = new Date()
    const time = new Date(createTime)

    if (isNaN(time.getTime())) return false

    const diffDays = Math.floor((now.getTime() - time.getTime()) / (1000 * 60 * 60 * 24))
    return diffDays <= 7
}

// 定义好友申请接口
export interface FriendRequest {
    id: string
    name: string
    avatar?: string
    phone?: string
    status: '待验证' | '已通过' | '已拒绝'
    time: string
    message?: string
    fromUserId?: string
    toUserId?: string
}

// 定义联系人接口
export interface Contact {
    id: string
    name: string
    avatar?: string
    avatarLocalPath?: string | null
    avatarObjectKey?: string | null
    phone: string
    email?: string
    isOnline: boolean
    lastSeen: string
    isRecent?: boolean
    remark?: string
    status: number
    createTime: string
    updateTime?: string
}

// 定义聊天列表项接口
export interface ChatItem {
    id: string
    roomId: string
    name: string
    avatar?: string | null
    avatarLocalPath?: string | null
    lastMessage: string
    time: string
    groupId: string
    memberCount?: number
    unreadCount: number
    isTop: boolean
    isHidden?: boolean
    groupType: number // 0=单聊, 1=群聊, 2=收藏夹
    lastMessageId?: string | null
    chatStatus?: number
    groupNotice?: string | null
    showNoticeFlag?: boolean
    userAvatar?: string | null
    friendName?: string | null
    remark?: string | null
    extra?: Record<string, unknown> | null
}

// 全局用户资料结构（用于统一管理昵称 / 头像等）
export interface UserProfile {
    userId: string
    username?: string | null
    nickname?: string | null
    avatarUrl?: string | null
    avatarObjectKey?: string | null
}

const sortChatItems = (list: ChatItem[], currentChatGroupId?: string | null) => {
    list.sort((a, b) => {
        const aIsFavorite = a.groupType === 2
        const bIsFavorite = b.groupType === 2

        if (aIsFavorite && !bIsFavorite) return -1
        if (!aIsFavorite && bIsFavorite) return 1

        if (a.isTop && !b.isTop) return -1
        if (!a.isTop && b.isTop) return 1

        // 当前选中的会话优先显示（在收藏夹和置顶之后）
        const aIsCurrent = currentChatGroupId && (a.groupId === currentChatGroupId || a.id === currentChatGroupId)
        const bIsCurrent = currentChatGroupId && (b.groupId === currentChatGroupId || b.id === currentChatGroupId)

        if (aIsCurrent && !bIsCurrent) return -1
        if (!aIsCurrent && bIsCurrent) return 1

        // 时间倒序（最新消息在前）
        return new Date(b.time).getTime() - new Date(a.time).getTime()
    })
}

const applyMessageRuntimeToChatList = (
    state: State,
    nextRuntime: MessageRuntimeSettings,
    previousRuntime: MessageRuntimeSettings,
) => {
    if (!didEnterRelayOnlyMode(previousRuntime, nextRuntime)) {
        return
    }

    state.chatList.list = sanitizeChatSummariesForRuntime(nextRuntime, state.chatList.list)
}

const persistRelayOnlyChatListIfNeeded = async (
    state: State,
    dispatch: any,
    previousRuntime: MessageRuntimeSettings,
    nextRuntime: MessageRuntimeSettings,
) => {
    if (!didEnterRelayOnlyMode(previousRuntime, nextRuntime) || state.chatList.list.length === 0) {
        return
    }

    const currentAccountId = state.accounts?.currentAccountId
    if (currentAccountId) {
        dispatch('accounts/syncAccountUnreadCount', currentAccountId)
    }

    await saveCache(CACHE_KEYS.chatList, JSON.parse(JSON.stringify(state.chatList.list)))
}

// 定义状态接口
export interface State {
    token: string | null,
    // 刷新令牌：用于在访问令牌过期后无感刷新
    refreshToken: string | null,
    user: {
        id: string | null
        username: string | null
        nickname: string | null
        avatar: string | null
        avatarObjectKey: string | null
        avatarLocalPath: string | null
        mobile: string | null
        email: string | null
        isLoggedIn: boolean
        // 添加更多用户信息字段，与登录响应保持一致
        realName?: string | null
        chatNumber?: string | null
        address?: string | null
        createTime?: string | null
        lastLoginTime?: string | null
        activeStatus?: number | null
        delFlag?: number | null
        level?: number | null
        userDeviceId?: string | null
        userSign?: string | null
        trcSdkAppId?: number | null
        powerList?: any[] | null
    }
    version: {
        current: {
            buildNumber: number
            version: string
            channel: string
        }
        latest: {
            hasUpdate: boolean
            info: AppVersionInfo | null
            checking: boolean
            error: string | null
        }
    }
    theme: 'light' | 'dark'
    loading: boolean
    sidebarWidth: number
    websocket: WebSocket | null
    networkState: boolean
    currentChatGroupId: string | null
    // 聊天列表滚动请求（用于 UI 定位，不改变当前选中会话）
    chatListScrollRequest: { groupId: string | null; align?: 'top' | 'center' | 'bottom'; timestamp: number } | null
    // 新的朋友申请数量
    pendingFriendRequests: number
    // 全局加载蒙版状态
    globalLoading: {
        visible: boolean
        text: string
    }
    // 联系人相关状态
    contacts: {
        list: Contact[]
        loading: boolean
        error: string | null
        searchKeyword: string
        lastUpdateTime: number | null
    }
    // 聊天列表相关状态
    chatList: {
        list: ChatItem[]
        loading: boolean
        error: string | null
        lastUpdateTime: number | null
    }
    // 好友申请相关状态
    friendRequests: {
        list: FriendRequest[]
        loading: boolean
        error: string | null
        lastUpdateTime: number | null
    }
    // 全局用户资料映射：key 为 userId
    userProfiles: Record<string, UserProfile>
    // 应用名称（从服务器加载）
    appName: string
    // 消息运行模式（从公开通用设置加载）
    messageRuntime: MessageRuntimeSettings
}

// 创建 store
export const store = createStore<State>({
    modules: {
        accounts: accountsModule
    },
    state: {
        token: null,
        refreshToken: null,
        user: {
            id: null,
            username: null,
            nickname: null,
            avatar: null,
            avatarObjectKey: null,
            avatarLocalPath: null,
            mobile: null,
            email: null,
            isLoggedIn: false,
            realName: null,
            chatNumber: null,
            address: null,
            createTime: null,
            lastLoginTime: null,
            activeStatus: null,
            delFlag: null,
            level: null,
            userDeviceId: null,
            userSign: null,
            trcSdkAppId: null,
            powerList: null
        },
        version: {
            current: {
                buildNumber: apiConfig.buildNumber ?? 100,
                version: apiConfig.version,
                channel: apiConfig.channel ?? 'stable'
            },
            latest: {
                hasUpdate: false,
                info: null,
                checking: false,
                error: null
            }
        },
        theme: 'light',
        loading: false,
        sidebarWidth: 300,
        websocket: null,
        networkState: false,
        currentChatGroupId: null,
        chatListScrollRequest: null,
        pendingFriendRequests: 0,
        globalLoading: {
            visible: false,
            text: '加载中...'
        },
        contacts: {
            list: [],
            loading: false,
            error: null,
            searchKeyword: '',
            lastUpdateTime: null
        },
        chatList: {
            list: [],
            loading: false,
            error: null,
            lastUpdateTime: null
        },
        friendRequests: {
            list: [],
            loading: false,
            error: null,
            lastUpdateTime: null
        },
        userProfiles: {},
        appName: 'Chatly', // 默认应用名称，启动时从服务器加载
        messageRuntime: { ...DEFAULT_MESSAGE_RUNTIME }
    },

    mutations: {
        // 授权 Token
        SET_TOKEN(state: State, token: string) {
            state.token = token
        },

        // 刷新 Token
        SET_REFRESH_TOKEN(state: State, refreshToken: string | null) {
            state.refreshToken = refreshToken
        },

        // 用户相关
        SET_USER(state: State, userInfo: {
            id: string;
            username: string;
            nickname: string;
            avatar: string;
            avatarObjectKey?: string | null;
            avatarLocalPath?: string | null;
            mobile: string;
            email: string;
            realName?: string;
            chatNumber?: string;
            address?: string;
            createTime?: string;
            lastLoginTime?: string;
            activeStatus?: number;
            delFlag?: number;
            level?: number;
            userDeviceId?: string;
            userSign?: string;
            trcSdkAppId?: number;
            powerList?: any[];
        }) {
            state.user.id = userInfo.id
            state.user.username = userInfo.username
            state.user.nickname = userInfo.nickname
            state.user.avatar = userInfo.avatar
            state.user.avatarObjectKey = userInfo.avatarObjectKey || null
            state.user.avatarLocalPath = userInfo.avatarLocalPath || null
            state.user.mobile = userInfo.mobile
            state.user.email = userInfo.email
            state.user.isLoggedIn = true
            // 设置扩展字段
            state.user.realName = userInfo.realName || null
            state.user.chatNumber = userInfo.chatNumber || null
            state.user.address = userInfo.address || null
            state.user.createTime = userInfo.createTime || null
            state.user.lastLoginTime = userInfo.lastLoginTime || null
            state.user.activeStatus = userInfo.activeStatus || null
            state.user.delFlag = userInfo.delFlag || null
            state.user.level = userInfo.level || null
            state.user.userDeviceId = userInfo.userDeviceId || null
            state.user.userSign = userInfo.userSign || null
            state.user.trcSdkAppId = userInfo.trcSdkAppId || null
            state.user.powerList = userInfo.powerList || null
        },

        UPDATE_USER_INFO(state: State, userInfo: Partial<{
            id: string;
            username: string;
            nickname: string;
            avatar: string;
            avatarObjectKey: string | null;
            avatarLocalPath: string | null;
            mobile: string;
            email: string;
        }>) {
            // ✅ 优化：使用 Object.assign 创建新对象引用，确保 Vue 响应式系统正确触发
            const updates: Partial<typeof state.user> = {}

            if (userInfo.id !== undefined) updates.id = userInfo.id
            if (userInfo.username !== undefined) updates.username = userInfo.username
            if (userInfo.nickname !== undefined) updates.nickname = userInfo.nickname
            if (userInfo.avatar !== undefined) updates.avatar = userInfo.avatar
            if (userInfo.avatarObjectKey !== undefined) updates.avatarObjectKey = userInfo.avatarObjectKey
            if (userInfo.avatarLocalPath !== undefined) updates.avatarLocalPath = userInfo.avatarLocalPath
            if (userInfo.mobile !== undefined) updates.mobile = userInfo.mobile
            if (userInfo.email !== undefined) updates.email = userInfo.email

            // 创建新对象引用，触发响应式更新
            state.user = Object.assign({}, state.user, updates)

        },

        // 写入或更新单个用户资料（用于好友资料变更等场景）
        UPSERT_USER_PROFILE(state: State, payload: UserProfile) {
            if (!payload || !payload.userId) return
            const userId = String(payload.userId)
            const existing = state.userProfiles[userId] || { userId }
            state.userProfiles = {
                ...state.userProfiles,
                [userId]: {
                    ...existing,
                    ...payload,
                    userId
                }
            }
        },

        // 批量写入或更新用户资料（例如加载联系人列表时）
        UPSERT_USER_PROFILES(state: State, profiles: UserProfile[]) {
            if (!Array.isArray(profiles) || profiles.length === 0) return
            const next = { ...state.userProfiles }
            for (const profile of profiles) {
                if (!profile || !profile.userId) continue
                const userId = String(profile.userId)
                const existing = next[userId] || { userId }
                next[userId] = {
                    ...existing,
                    ...profile,
                    userId
                }
            }
            state.userProfiles = next
        },

        SET_VERSION_CHECKING(state: State, checking: boolean) {
            state.version.latest.checking = checking
        },

        SET_VERSION_ERROR(state: State, message: string | null) {
            state.version.latest.error = message
        },

        SET_VERSION_INFO(state: State, payload: { hasUpdate: boolean; info: AppVersionInfo | null }) {
            state.version.latest.hasUpdate = payload.hasUpdate
            state.version.latest.info = payload.info
        },

        LOGOUT_USER(state: State) {
            state.user.id = null
            state.user.username = null
            state.user.nickname = null
            state.user.avatar = null
            state.user.avatarObjectKey = null
            state.user.avatarLocalPath = null
            state.user.mobile = null
            state.user.email = null
            state.user.isLoggedIn = false
            // 清理扩展字段
            state.user.realName = null
            state.user.chatNumber = null
            state.user.address = null
            state.user.createTime = null
            state.user.lastLoginTime = null
            state.user.activeStatus = null
            state.user.delFlag = null
            state.user.level = null
            state.user.userDeviceId = null
            state.user.userSign = null
            state.user.trcSdkAppId = null
            state.user.powerList = null
        },

        // 主题相关
        SET_THEME(state: State, theme: 'light' | 'dark') {
            state.theme = theme
        },

        // 加载状态
        SET_LOADING(state: State, loading: boolean) {
            state.loading = loading
        },

        // 侧边栏宽度
        SET_SIDEBAR_WIDTH(state: State, width: number) {
            state.sidebarWidth = width
        },

        // WebSocket 相关
        SET_WEBSOCKET(state: State, websocket: WebSocket | null) {
            state.websocket = websocket
        },

        SET_NETWORK_STATE(state: State, networkState: boolean) {
            state.networkState = networkState
        },

        SET_CURRENT_CHAT_GROUP_ID(state: State, groupId: string | null) {
            state.currentChatGroupId = groupId
        },

        // 记录一次性聊天列表滚动请求（携带时间戳以便重复触发）
        SET_CHAT_SCROLL_REQUEST(state: State, payload: { groupId: string | null; align?: 'top' | 'center' | 'bottom'; timestamp?: number } | null) {
            if (payload === null) {
                state.chatListScrollRequest = null
            } else {
                state.chatListScrollRequest = {
                    ...payload,
                    timestamp: payload.timestamp ?? Date.now()
                }
            }
        },

        // 设置待处理的好友申请数量
        SET_PENDING_FRIEND_REQUESTS(state: State, count: number) {
            state.pendingFriendRequests = count
        },
        SET_APP_NAME(state: State, appName: string) {
            state.appName = appName
        },
        SET_MESSAGE_RUNTIME(state: State, runtime: MessageRuntimeSettings) {
            const previousRuntime = state.messageRuntime
            state.messageRuntime = {
                serverStorageMode: runtime.serverStorageMode,
                contentAuditMode: runtime.contentAuditMode,
            }
            applyMessageRuntimeToChatList(state, state.messageRuntime, previousRuntime)
        },
        SET_GENERAL_SETTINGS(state: State, payload: { appName: string; messageRuntime: MessageRuntimeSettings }) {
            const previousRuntime = state.messageRuntime
            state.appName = payload.appName
            state.messageRuntime = {
                serverStorageMode: payload.messageRuntime.serverStorageMode,
                contentAuditMode: payload.messageRuntime.contentAuditMode,
            }
            applyMessageRuntimeToChatList(state, state.messageRuntime, previousRuntime)
        },

        // 全局加载蒙版控制
        SHOW_GLOBAL_LOADING(state: State, text: string = '加载中...') {
            state.globalLoading.visible = true
            state.globalLoading.text = text
        },

        HIDE_GLOBAL_LOADING(state: State) {
            state.globalLoading.visible = false
        },

        SET_GLOBAL_LOADING_TEXT(state: State, text: string) {
            state.globalLoading.text = text
        },

        // 联系人相关 mutations
        SET_CONTACTS_LOADING(state: State, loading: boolean) {
            state.contacts.loading = loading
        },

        SET_CONTACTS_LIST(state: State, contacts: Contact[]) {
            // 保留原有的直接设置功能，用于初始化或完全替换
            state.contacts.list = contacts
            state.contacts.lastUpdateTime = Date.now()
            state.contacts.error = null
        },

        SYNC_CONTACTS_LIST(state: State, newContacts: Contact[]) {
            // 实现智能合并逻辑：比对新旧数据，删除不存在的，添加新增的，更新变化的
            const currentContacts = state.contacts.list
            const currentContactIds = new Set(currentContacts.map(c => c.id))
            const newContactIds = new Set(newContacts.map(c => c.id))

            // 1. 找出需要删除的联系人（在旧数据中但不在新数据中）
            const contactsToRemove = currentContacts.filter(contact => !newContactIds.has(contact.id))
            contactsToRemove.forEach(contact => {
                const index = state.contacts.list.findIndex(c => c.id === contact.id)
                if (index !== -1) {
                    state.contacts.list.splice(index, 1)
                }
            })

            // 2. 找出需要添加的联系人（在新数据中但不在旧数据中）
            const contactsToAdd = newContacts.filter(contact => !currentContactIds.has(contact.id))
            contactsToAdd.forEach(contact => {
                state.contacts.list.push(contact)
            })

            // 3. 更新已存在的联系人信息
            newContacts.forEach(newContact => {
                if (currentContactIds.has(newContact.id)) {
                    const index = state.contacts.list.findIndex(c => c.id === newContact.id)
                    if (index !== -1) {
                        const currentContact = state.contacts.list[index]
                        // 只在数据发生变化时才更新
                        const hasChanged = (
                            currentContact.name !== newContact.name ||
                            currentContact.phone !== newContact.phone ||
                            currentContact.avatar !== newContact.avatar ||
                            currentContact.status !== newContact.status ||
                            currentContact.updateTime !== newContact.updateTime
                        )

                        if (hasChanged) {
                            state.contacts.list.splice(index, 1, newContact)
                        }
                    }
                }
            })

            // 4. 更新最后更新时间和清除错误状态
            state.contacts.lastUpdateTime = Date.now()
            state.contacts.error = null

        },

        SET_CONTACTS_ERROR(state: State, error: string | null) {
            state.contacts.error = error
        },

        SET_CONTACTS_SEARCH_KEYWORD(state: State, keyword: string) {
            state.contacts.searchKeyword = keyword
        },

        CLEAR_CONTACTS(state: State) {
            state.contacts.list = []
            state.contacts.loading = false
            state.contacts.error = null
            state.contacts.searchKeyword = ''
            state.contacts.lastUpdateTime = null
        },

        UPDATE_CONTACT(state: State, updatedContact: Contact) {
            const index = state.contacts.list.findIndex(contact => contact.id === updatedContact.id)
            if (index !== -1) {
                state.contacts.list.splice(index, 1, updatedContact)
            }
        },

        ADD_CONTACT(state: State, newContact: Contact) {
            const exists = state.contacts.list.some(contact => contact.id === newContact.id)
            if (!exists) {
                state.contacts.list.push(newContact)
            }
        },

        REMOVE_CONTACT(state: State, contactId: string) {
            state.contacts.list = state.contacts.list.filter(contact => contact.id !== contactId)
        },

        // 聊天列表相关 mutations
        SET_CHAT_LIST_LOADING(state: State, loading: boolean) {
            state.chatList.loading = loading
        },

        SET_CHAT_LIST(state: State, chatList: ChatItem[]) {
            // 保留原有的直接设置功能，用于初始化或完全替换
            const sortedChatList = [...chatList]
            sortChatItems(sortedChatList, state.currentChatGroupId)
            state.chatList.list = sortedChatList
            state.chatList.lastUpdateTime = Date.now()
            state.chatList.error = null
        },

        SET_CHAT_LIST_ERROR(state: State, message: string | null) {
            state.chatList.error = message
        },

        SYNC_CHAT_LIST(state: State, newChatList: ChatItem[]) {
            // 实现智能合并逻辑：比对新旧数据，删除不存在的，添加新增的，更新变化的
            const currentChats = state.chatList.list
            const currentChatIds = new Set(currentChats.map(c => c.id))
            const newChatIds = new Set(newChatList.map(c => c.id))

            // 1. 找出需要删除的聊天（在旧数据中但不在新数据中）
            const chatsToRemove = currentChats.filter(chat => !newChatIds.has(chat.id))
            chatsToRemove.forEach(chat => {
                const index = state.chatList.list.findIndex(c => c.id === chat.id)
                if (index !== -1) {
                    state.chatList.list.splice(index, 1)
                }
            })

            // 2. 找出需要添加的聊天（在新数据中但不在旧数据中）
            const chatsToAdd = newChatList.filter(chat => !currentChatIds.has(chat.id))
            chatsToAdd.forEach(chat => {
                state.chatList.list.push(chat)
            })

            // 3. 更新已存在的聊天信息
            newChatList.forEach(newChat => {
                if (currentChatIds.has(newChat.id)) {
                    const index = state.chatList.list.findIndex(c => c.id === newChat.id)
                    if (index !== -1) {
                        const currentChat = state.chatList.list[index]
                        // 只在数据发生变化时才更新
                        const hasChanged = (
                            currentChat.name !== newChat.name ||
                            currentChat.lastMessage !== newChat.lastMessage ||
                            currentChat.time !== newChat.time ||
                            currentChat.unreadCount !== newChat.unreadCount ||
                            currentChat.isTop !== newChat.isTop ||
                            currentChat.isHidden !== newChat.isHidden
                        )

                        if (hasChanged) {
                            state.chatList.list.splice(index, 1, newChat)
                        }
                    }
                }
            })

            // 4. 重新排序（收藏夹优先，其次置顶，再按时间倒序，当前选中会话优先）
            sortChatItems(state.chatList.list, state.currentChatGroupId)

            // 5. 更新最后更新时间和清除错误状态
            state.chatList.lastUpdateTime = Date.now()
            state.chatList.error = null

        },

        UPDATE_CHAT_ITEM(state: State, updatedChat: ChatItem) {
            const index = state.chatList.list.findIndex(chat => chat.id === updatedChat.id)
            if (index !== -1) {
                state.chatList.list.splice(index, 1, updatedChat)
                // 重新排序，确保当前选中会话优先
                sortChatItems(state.chatList.list, state.currentChatGroupId)
            }
        },

        SET_CHAT_UNREAD_COUNT(state: State, payload: { groupId: string; unreadCount: number }) {
            const { groupId, unreadCount } = payload
            const chat = state.chatList.list.find(item => item.groupId === groupId || item.id === groupId)
            if (chat) {
                chat.unreadCount = Math.max(0, unreadCount)
            }
        },

        ADD_CHAT_ITEM(state: State, newChat: ChatItem) {
            const exists = state.chatList.list.some(chat => chat.id === newChat.id)
            if (!exists) {
                state.chatList.list.push(newChat)
                // 重新排序，确保当前选中会话优先
                sortChatItems(state.chatList.list, state.currentChatGroupId)
            }
        },

        REMOVE_CHAT_ITEM(state: State, chatId: string) {
            // ...

            const beforeCount = state.chatList.list.length
            state.chatList.list = state.chatList.list.filter(chat => {
                const shouldRemove = chat.id === chatId || chat.groupId === chatId
                if (shouldRemove && state.currentChatGroupId === chat.groupId) {
                    state.currentChatGroupId = null
                }
                return !shouldRemove
            })
            const afterCount = state.chatList.list.length

        },

        // 好友申请相关 mutations
        SET_FRIEND_REQUESTS_LOADING(state: State, loading: boolean) {
            state.friendRequests.loading = loading
        },

        SET_FRIEND_REQUESTS_LIST(state: State, friendRequests: FriendRequest[]) {
            // 保留原有的直接设置功能，用于初始化或完全替换
            state.friendRequests.list = friendRequests
            state.friendRequests.lastUpdateTime = Date.now()
            state.friendRequests.error = null
        },

        SYNC_FRIEND_REQUESTS_LIST(state: State, newFriendRequests: FriendRequest[]) {
            // 实现智能合并逻辑：比对新旧数据，删除不存在的，添加新增的，更新变化的
            const currentRequests = state.friendRequests.list
            const currentRequestIds = new Set(currentRequests.map(r => r.id))
            const newRequestIds = new Set(newFriendRequests.map(r => r.id))

            // 1. 找出需要删除的好友申请（在旧数据中但不在新数据中）
            const requestsToRemove = currentRequests.filter(request => !newRequestIds.has(request.id))
            requestsToRemove.forEach(request => {
                const index = state.friendRequests.list.findIndex(r => r.id === request.id)
                if (index !== -1) {
                    state.friendRequests.list.splice(index, 1)
                }
            })

            // 2. 找出需要添加的好友申请（在新数据中但不在旧数据中）
            const requestsToAdd = newFriendRequests.filter(request => !currentRequestIds.has(request.id))
            requestsToAdd.forEach(request => {
                state.friendRequests.list.push(request)
            })

            // 3. 更新已存在的好友申请信息
            newFriendRequests.forEach(newRequest => {
                if (currentRequestIds.has(newRequest.id)) {
                    const index = state.friendRequests.list.findIndex(r => r.id === newRequest.id)
                    if (index !== -1) {
                        const currentRequest = state.friendRequests.list[index]
                        // 只在数据发生变化时才更新
                        const hasChanged = (
                            currentRequest.name !== newRequest.name ||
                            currentRequest.status !== newRequest.status ||
                            currentRequest.message !== newRequest.message ||
                            currentRequest.time !== newRequest.time
                        )

                        if (hasChanged) {
                            state.friendRequests.list.splice(index, 1, newRequest)
                        }
                    }
                }
            })

            // 4. 按时间排序（最新的在前）
            state.friendRequests.list.sort((a, b) => {
                return new Date(b.time).getTime() - new Date(a.time).getTime()
            })

            // 5. 更新最后更新时间和清除错误状态
            state.friendRequests.lastUpdateTime = Date.now()
            state.friendRequests.error = null

        },

        SET_FRIEND_REQUESTS_ERROR(state: State, error: string | null) {
            state.friendRequests.error = error
        },

        CLEAR_FRIEND_REQUESTS(state: State) {
            state.friendRequests.list = []
            state.friendRequests.loading = false
            state.friendRequests.error = null
            state.friendRequests.lastUpdateTime = null
        },

        UPDATE_FRIEND_REQUEST(state: State, updatedRequest: FriendRequest) {
            const index = state.friendRequests.list.findIndex(request => request.id === updatedRequest.id)
            if (index !== -1) {
                state.friendRequests.list.splice(index, 1, updatedRequest)
                // 重新排序
                state.friendRequests.list.sort((a, b) => {
                    return new Date(b.time).getTime() - new Date(a.time).getTime()
                })
            }
        },

        ADD_FRIEND_REQUEST(state: State, newRequest: FriendRequest) {
            const exists = state.friendRequests.list.some(request => request.id === newRequest.id)
            if (!exists) {
                state.friendRequests.list.unshift(newRequest) // 添加到开头
                // 重新排序
                state.friendRequests.list.sort((a, b) => {
                    return new Date(b.time).getTime() - new Date(a.time).getTime()
                })
            }
        },

        REMOVE_FRIEND_REQUEST(state: State, requestId: string) {
            state.friendRequests.list = state.friendRequests.list.filter(request => request.id !== requestId)
        },

        // 更新当前聊天群头像
        UPDATE_CURRENT_CHAT_AVATAR(state: State, payload: { groupId: string; avatarUrl: string }) {
            const { groupId, avatarUrl } = payload;
            // 更新聊天列表中对应群聊的头像
            const chatItem = state.chatList.list.find(item => item.groupId === groupId);
            if (chatItem) {
                chatItem.avatar = avatarUrl;
                chatItem.avatarLocalPath = undefined; // 清除本地缓存，等待重新下载
            }
        }
    },

    actions: {
        // 加载公开通用设置（静默加载，失败不影响启动）
        async loadGeneralSettings({ commit, state, dispatch }: { commit: any; state: State; dispatch: any }) {
            let hasAppliedCachedSettings = false

            try {
                const cached = await loadCache<GeneralSettingsPayload>(CACHE_KEYS.generalSettings)
                if (cached?.data) {
                    const resolved = resolveGeneralSettingsPayload(cached.data)
                    const previousRuntime = state.messageRuntime
                    commit('SET_GENERAL_SETTINGS', resolved)
                    await persistRelayOnlyChatListIfNeeded(state, dispatch, previousRuntime, resolved.messageRuntime)
                    hasAppliedCachedSettings = true
                }
            } catch (error) {
                // ignore cache failures
            }

            try {
                const response = await SettingsApi.getGeneralSettings()
                const generalSettings = response?.data ?? null
                let legacyAppName: string | null = null

                if (!generalSettings?.app_name?.trim()) {
                    const legacyResponse = await SettingsApi.getAppName()
                    legacyAppName = legacyResponse?.data?.app_name ?? null
                }

                const resolved = resolveGeneralSettingsPayload(generalSettings, legacyAppName)
                const previousRuntime = state.messageRuntime
                commit('SET_GENERAL_SETTINGS', resolved)
                await saveCache(CACHE_KEYS.generalSettings, serializeGeneralSettingsPayload(resolved))
                await persistRelayOnlyChatListIfNeeded(state, dispatch, previousRuntime, resolved.messageRuntime)
            } catch (error) {
                if (!hasAppliedCachedSettings) {
                    try {
                        const legacyResponse = await SettingsApi.getAppName()
                        const resolved = resolveGeneralSettingsPayload(null, legacyResponse?.data?.app_name ?? null)
                        const previousRuntime = state.messageRuntime
                        commit('SET_GENERAL_SETTINGS', resolved)
                        await saveCache(CACHE_KEYS.generalSettings, serializeGeneralSettingsPayload(resolved))
                        await persistRelayOnlyChatListIfNeeded(state, dispatch, previousRuntime, resolved.messageRuntime)
                    } catch (legacyError) {
                        console.warn('Failed to load general settings from server, using defaults')
                    }
                }
            }
        },
        // 兼容旧调用入口
        async loadAppName({ dispatch }: { dispatch: any }) {
            await dispatch('loadGeneralSettings')
        },
        // 登录
        async login({ commit, state, getters, dispatch }: { commit: any; state: any; getters: any; dispatch: any }, loginData: {
            token: string;
            refreshToken?: string | null;
            userInfo: {
                id: string;
                username: string;
                nickname: string;
                avatar: string;
                mobile: string;
                email: string;
                // 添加可选字段
                realName?: string;
                chatNumber?: string;
                address?: string;
                createTime?: string;
                lastLoginTime?: string;
                activeStatus?: number;
                delFlag?: number;
                level?: number;
                userDeviceId?: string;
                userSign?: string;
                trcSdkAppId?: number;
                powerList?: any[];
            };
            expiresIn?: number;
        }) {
            try {
                // 登录前先清理任何残留状态，确保干净的登录环境

                // 取消所有pending的请求，避免旧请求干扰新的登录状态
                try {
                    const { cancelAllPendingRequests, setLoggingOut } = await import('../api/http');
                    cancelAllPendingRequests();
                    setLoggingOut(false); // 重置登出状态
                } catch (httpError) {
                }

                // 清理其他状态
                try {
                    commit('SET_WEBSOCKET', null);
                    commit('SET_NETWORK_STATE', false);
                    commit('SET_CURRENT_CHAT_GROUP_ID', null);
                    commit('SET_PENDING_FRIEND_REQUESTS', 0);
                } catch (commitError) {
                }

                // 设置token和用户信息

                try {
                    commit('SET_TOKEN', loginData.token);
                } catch (tokenError) {
                    throw tokenError;
                }

                // 保存刷新令牌（仅在调用方显式提供时更新，避免误清空）
                if ('refreshToken' in loginData) {
                    try {
                        commit('SET_REFRESH_TOKEN', loginData.refreshToken ?? null);
                    } catch (e) {
                    }
                }

                try {
                    const { syncRustBackendToken } = await import('../api/http');
                    await syncRustBackendToken(loginData.token);
                } catch (syncError) {
                }

                try {
                    commit('SET_USER', loginData.userInfo);
                } catch (userError) {
                    throw userError;
                }

                try {
                    await UserApi.syncAvatarCache(true);
                } catch (cacheError) {
                }

                try {
                    await dispatch('checkAppUpdate');
                } catch (versionError) {
                }

                // 立即验证token是否正确设置
                const verifyToken = state.token;
                const verifyLoggedIn = getters.isLoggedIn;

                // 注意：不使用localStorage持久化存储
                // 因为应用需求是每次打开都要重新登录

                return { success: true, userInfo: loginData.userInfo, token: loginData.token };
            } catch (error) {
                throw new Error(`登录失败: ${error instanceof Error ? error.message : '未知错误'}`);
            }
        },

        // 登出 - 显示加载蒙版，快速清除客户端状态，立即关闭WebSocket防止账户混乱
        async logout({ commit, state, dispatch, rootGetters }: { commit: any; state: State; dispatch: any; rootGetters: any }) {
            const logoutId = `LOGOUT_${Date.now()}`;

            // 如果已经处于未登录状态，立即收起蒙版并退出
            if (!state.token && !state.user.isLoggedIn) {
                commit('HIDE_GLOBAL_LOADING')
                return
            }

            const accountList: AccountInfo[] = (rootGetters['accounts/allAccounts'] as AccountInfo[] | undefined) || []
            const accountIds = accountList.map(account => account.id)

            for (const accountId of accountIds) {
                try {
                    await dispatch('accounts/logoutAccount', accountId)
                } catch (error) {
                }
            }

            // 第一步：显示加载蒙版
            commit('SHOW_GLOBAL_LOADING', '正在退出登录...')

            // 第二步：立即设置登出状态，取消所有pending请求
            import('../api/http').then(({ setLoggingOut, cancelAllPendingRequests, syncRustBackendToken }) => {
                setLoggingOut(true);
                cancelAllPendingRequests();
                syncRustBackendToken(null).catch(() => { });
            }).catch((error) => {
            })

            // 第三步：立即关闭WebSocket连接，防止账户切换混乱
            import('../utils/websocket').then(({ webSocketManager }) => {
                webSocketManager.closeWebSocket()
            }).catch((error) => {
                // 即使WebSocket关闭失败，也要清除状态
                commit('SET_WEBSOCKET', null)
                commit('SET_NETWORK_STATE', false)
            })

            // 第四步：立即清除WebSocket相关状态和联系人数据
            commit('SET_WEBSOCKET', null)
            commit('SET_NETWORK_STATE', false)
            commit('SET_CURRENT_CHAT_GROUP_ID', null)
            commit('SET_PENDING_FRIEND_REQUESTS', 0)
            commit('CLEAR_CONTACTS')
            commit('CLEAR_CHAT_LIST') // 清除聊天列表数据
            commit('CLEAR_FRIEND_REQUESTS') // 清除好友申请数据

            // 第五步：后台异步处理服务端清理工作，带超时保护
            setTimeout(() => {
                // 更新加载文字
                commit('SET_GLOBAL_LOADING_TEXT', '退出中')

                // 强制清除认证状态的函数
                const forceLogout = async () => {
                    commit('SET_TOKEN', null)
                    commit('SET_REFRESH_TOKEN', null)
                    commit('LOGOUT_USER')

                    // 重置登出状态，允许用户重新登录
                    try {
                        const { setLoggingOut } = await import('../api/http')
                        setLoggingOut(false)
                    } catch (error) {
                    }

                    // 重置窗口标题
                    try {
                        const { updateWindowTitle } = await import('../utils')
                        await updateWindowTitle(undefined, state.appName) // 显示默认标题
                    } catch (error) {
                    }


                    // 确保全局加载蒙版被关闭
                    commit('HIDE_GLOBAL_LOADING')
                }

                // 设置超时保护，确保1.5秒内必须清除token
                const timeoutId = setTimeout(() => {
                    forceLogout()
                }, 1500)

                // 尝试调用服务端登出接口
                try {
                    import('../api/system').then(({ SystemApi }) => {
                        return SystemApi.logout()
                    }).then(() => {
                    }).catch((error) => {
                    }).finally(() => {
                        // 清除超时定时器
                        clearTimeout(timeoutId)
                        // 清除认证状态
                        forceLogout()
                    })
                } catch (error) {
                    // 清除超时定时器
                    clearTimeout(timeoutId)
                    // 立即清除认证状态
                    forceLogout()
                }

            }, 300) // 给用户一点反馈时间

        },

        // 切换主题
        toggleTheme({ commit, state }: { commit: any; state: State }) {
            const newTheme = state.theme === 'light' ? 'dark' : 'light'
            commit('SET_THEME', newTheme)
        },

        // 设置侧边栏宽度
        setSidebarWidth({ commit }: { commit: any }, width: number) {
            commit('SET_SIDEBAR_WIDTH', width)
        },

        // 更新待处理的好友申请数量
        async updatePendingFriendRequests({ commit, dispatch, state }: { commit: any; dispatch: any; state: State }) {
            try {
                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.getPendingFriendRequestCount()

                if (response.success && typeof response.data === 'number') {
                    // 更新全局状态
                    commit('SET_PENDING_FRIEND_REQUESTS', response.data)

                    // 同步到当前账号
                    const currentAccountId = state.accounts?.currentAccountId
                    if (currentAccountId) {
                        // 调用账号模块的 mutation
                        commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
                            accountId: currentAccountId,
                            count: response.data
                        }, { root: true })
                    }
                } else {
                    commit('SET_PENDING_FRIEND_REQUESTS', 0)
                }
            } catch (error) {
                // 如果发生错误，使用默认值0
                commit('SET_PENDING_FRIEND_REQUESTS', 0)
            }
        },

        // 显示全局加载
        showGlobalLoading({ commit }: { commit: any }, text: string = '加载中...') {
            commit('SHOW_GLOBAL_LOADING', text)
        },

        // 隐藏全局加载
        hideGlobalLoading({ commit }: { commit: any }) {
            commit('HIDE_GLOBAL_LOADING')
        },

        // 更新全局加载文字
        updateGlobalLoadingText({ commit }: { commit: any }, text: string) {
            commit('SET_GLOBAL_LOADING_TEXT', text)
        },

        // 检查应用更新
        async checkAppUpdate({ state, commit }: { state: State; commit: any }) {
            commit('SET_VERSION_CHECKING', true)
            commit('SET_VERSION_ERROR', null)
            try {
                const response = await VersionApi.getLatestVersion({
                    channel: state.version.current.channel,
                    currentVersion: state.version.current.version
                })
                if (!response.success || !response.data) {
                    throw new Error(response.message || '版本查询失败')
                }
                const { has_update, version } = response.data
                commit('SET_VERSION_INFO', {
                    hasUpdate: !!has_update && !!version,
                    info: version || null
                })
            } catch (error: any) {
                const message = error?.message || '检查更新失败'
                commit('SET_VERSION_ERROR', message)
                commit('SET_VERSION_INFO', { hasUpdate: false, info: null })
            } finally {
                commit('SET_VERSION_CHECKING', false)
            }
        },

        // 下载最新版本
        async downloadLatestVersion({ state, commit }: { state: State; commit: any }) {
            const latest = state.version.latest.info
            if (!latest) {
                commit('SET_VERSION_ERROR', '暂无可用更新')
                return
            }
            try {
                const response = await VersionApi.getDownloadUrl({
                    id: latest.id,
                    expiresInSeconds: 600
                })
                if (!response.success || !response.data || !response.data.download_url) {
                    throw new Error(response.message || '获取下载链接失败')
                }
                const computeFileName = () => {
                    const key = latest.download_key || ''
                    const normalized = key.split('?')[0]
                    const baseName = normalized.split('/').pop()?.trim()
                    if (baseName && baseName.length > 0) {
                        return baseName
                    }
                    const extension = latest.platform === 'macos'
                        ? '.dmg'
                        : latest.platform === 'windows'
                            ? '.exe'
                            : '.AppImage'
                    return `Chatly-${latest.platform || 'app'}-${latest.version}${extension}`
                }
                return {
                    downloadUrl: response.data.download_url,
                    fileName: computeFileName()
                }
            } catch (error: any) {
                const message = error?.message || '下载更新失败'
                commit('SET_VERSION_ERROR', message)
                throw error
            }
        },

        // 加载联系人列表
        async loadContacts({ commit, state }: { commit: any; state: State }, params: { keyword?: string; forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            const isSearchMode = Boolean(params.keyword && params.keyword.trim().length > 0)
            let shouldResetLoading = false

            try {
                commit('SET_CONTACTS_ERROR', null)

                if (!isSearchMode && state.contacts.list.length === 0 && !params.forceRefresh) {
                    const cached = await loadCache<Contact[]>(CACHE_KEYS.contacts)
                    if (cached?.data && Array.isArray(cached.data) && cached.data.length > 0) {
                        commit('SET_CONTACTS_LIST', cached.data)
                    }
                }

                const shouldShowLoading = isSearchMode
                    || state.contacts.list.length === 0
                    || params.forceRefresh === true
                if (shouldShowLoading) {
                    commit('SET_CONTACTS_LOADING', true)
                    shouldResetLoading = true
                }

                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.getMyFriendList({
                    keyword: params.keyword || '',
                    page: 1,
                    size: 1000 // 获取所有联系人
                })

                if (response.success && Array.isArray(response.data)) {
                    // 导入 UserApi
                    const { UserApi } = await import('../api/user')

                    // 先创建基础 Contact 对象
                    const contacts: Contact[] = response.data.map((friend: any) => {
                        const user = friend.user || {}

                        // 优先显示好友备注，如果没有备注则显示昵称或用户名
                        const displayName = friend.friendRemark?.trim() || user.nickname?.trim() || user.username || '未知用户'
                        const createdAt: Date = friend.createdAt instanceof Date ? friend.createdAt : new Date(friend.createdAt)
                        const createdAtIso = isNaN(createdAt.getTime()) ? new Date() : createdAt

                        return {
                            id: user.id?.toString() || friend.id?.toString() || '',
                            name: displayName,
                            avatar: user.avatarUrl || '',
                            avatarLocalPath: null, // 将在下面填充(从本地缓存或下载)
                            avatarObjectKey: user.avatarObjectKey || null,
                            phone: user.username || '',
                            email: user.email || '',
                            isOnline: false,
                            lastSeen: formatLastSeen(createdAtIso.toISOString()),
                            isRecent: isRecentContact(createdAtIso.toISOString()),
                            remark: friend.friendRemark || user.nickname || '',
                            status: 1,
                            createTime: createdAtIso.toISOString(),
                            updateTime: createdAtIso.toISOString()
                        }
                    })

                    // 同步联系人对应的用户资料到全局 userProfiles 映射
                    const profiles: UserProfile[] = response.data
                        .map((friend: any) => {
                            const user = friend.user || {}
                            const rawId = user.id ?? friend.id
                            if (!rawId) return null
                            const userId = rawId.toString()
                            return {
                                userId,
                                username: user.username || null,
                                nickname: user.nickname || null,
                                avatarUrl: user.avatarUrl || null,
                                avatarObjectKey: user.avatarObjectKey || null
                            } as UserProfile
                        })
                        .filter((item: UserProfile | null): item is UserProfile => !!item)

                    if (profiles.length > 0) {
                        commit('UPSERT_USER_PROFILES', profiles)
                    }

                    // 智能同步用户头像缓存:
                    // 1. 优先从本地缓存读取(基于 objectKey 检查)
                    // 2. objectKey 不匹配或缓存不存在时:
                    //    - 获取临时下载地址
                    //    - 下载到本地
                    //    - 返回本地 Blob URL
                    await Promise.all(
                        contacts.map(async (contact) => {
                            if (!contact.avatarObjectKey) {
                                return
                            }

                            try {
                                // syncUserAvatarCache 会:
                                // 1. 检查本地缓存(基于 objectKey)
                                // 2. 缓存命中直接返回 Blob URL
                                // 3. 缓存未命中则下载并保存
                                const localPath = await UserApi.syncUserAvatarCache(
                                    contact.id,
                                    contact.avatarObjectKey,
                                    false // 不强制刷新,优先使用缓存
                                )
                                if (localPath) {
                                    contact.avatarLocalPath = localPath
                                }
                            } catch (error) {
                                // 静默失败,使用默认头像
                            }
                        })
                    )

                    // 根据参数选择使用同步模式还是替换模式
                    if (params.compareWithStore && state.contacts.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_CONTACTS_LIST', contacts)
                    } else {
                        // 直接替换，用于首次加载或搜索
                        commit('SET_CONTACTS_LIST', contacts)
                    }

                    if (params.keyword) {
                        commit('SET_CONTACTS_SEARCH_KEYWORD', params.keyword)
                    }


                    if (!isSearchMode) {
                        const snapshot = JSON.parse(JSON.stringify(contacts)) as Contact[]
                        await saveCache(CACHE_KEYS.contacts, snapshot)
                    }
                } else {
                    commit('SET_CONTACTS_ERROR', response.message || '加载联系人列表失败')
                }
            } catch (error: any) {
                commit('SET_CONTACTS_ERROR', error.message || '网络错误，请稍后重试')
            } finally {
                if (shouldResetLoading) {
                    commit('SET_CONTACTS_LOADING', false)
                }
            }
        },

        // 搜索联系人
        async searchContacts({ dispatch }: { dispatch: any }, keyword: string) {
            return dispatch('loadContacts', { keyword, forceRefresh: true })
        },

        // 清空联系人列表
        clearContacts({ commit }: { commit: any }) {
            commit('CLEAR_CONTACTS')
        },

        // 刷新联系人列表
        async refreshContacts({ dispatch }: { dispatch: any }) {
            return dispatch('loadContacts', { forceRefresh: true })
        },

        // 聊天列表相关 actions
        // 加载聊天列表
        async loadChatList({ commit, state, dispatch }: { commit: any; state: State; dispatch: any }, params: { forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            const { forceRefresh = false, compareWithStore = false } = params
            let shouldResetLoading = false
            try {
                commit('SET_CHAT_LIST_ERROR', null)

                if (!forceRefresh && state.chatList.list.length === 0) {
                    const cached = await loadCache<ChatItem[]>(CACHE_KEYS.chatList)
                    if (cached?.data && Array.isArray(cached.data) && cached.data.length > 0) {
                        // 清除缓存中的头像 URL 和 LocalPath，等待后续同步
                        const sanitizedData = cached.data.map(chat => ({
                            ...chat,
                            avatar: undefined,
                            avatarLocalPath: undefined,
                        })).map(chat => sanitizeChatSummaryForRuntime(state.messageRuntime, chat))
                        commit('SET_CHAT_LIST', sanitizedData)
                    }
                }

                const shouldShowLoading = forceRefresh || state.chatList.list.length === 0
                if (shouldShowLoading) {
                    commit('SET_CHAT_LIST_LOADING', true)
                    shouldResetLoading = true
                }

                // 导入 GroupApi 并调用 API
                const { GroupApi } = await import('../api/group')
                const response = await GroupApi.getMyChatGroupList()

                if (response.success && Array.isArray(response.data)) {
                    const groups = response.data

                    const contactsMap = new Map<string, any>((state.contacts?.list || []).map((contact: any) => [String(contact.id), contact]))
                    const currentNameSet = new Set<string>()
                    const pushName = (value?: any) => {
                        if (typeof value === 'string') {
                            const trimmed = value.trim()
                            if (trimmed.length > 0) {
                                currentNameSet.add(trimmed)
                            }
                        }
                    }

                    pushName(state.user?.nickname)
                    pushName(state.user?.username)
                    pushName(state.user?.realName)
                    pushName(state.user?.chatNumber)

                    const normalizeString = (value: any): string | null => {
                        if (typeof value !== 'string') return null
                        const trimmed = value.trim()
                        return trimmed.length > 0 ? trimmed : null
                    }

                    const resolvePrivateChatDisplay = (group: any): { name: string; friendName?: string | null; avatar?: string | null } => {
                        const rawName = normalizeString(group.name) || '未命名会话'
                        const extra = (group.extra && typeof group.extra === 'object') ? group.extra : {}

                        const friendIdCandidates = [
                            extra?.friend_id,
                            extra?.friendId,
                            extra?.friend_user_id,
                            extra?.friendUserId,
                            extra?.target_user_id,
                            extra?.targetUserId,
                            extra?.peer_user_id,
                            extra?.peerUserId,
                            extra?.user_id,
                            extra?.userId,
                        ]

                        let friendId: string | null = null
                        for (const candidate of friendIdCandidates) {
                            const normalized = normalizeString(candidate)
                            if (normalized) {
                                friendId = normalized
                                break
                            }
                        }

                        const nameCandidates = [
                            extra?.friend_remark,
                            extra?.friendRemark,
                            extra?.remark,
                            extra?.friend_nickname,
                            extra?.friendNickname,
                            extra?.nickname,
                            extra?.friend_name,
                            extra?.friendName,
                            extra?.display_name,
                            extra?.displayName,
                        ]

                        let resolvedName: string | null = null
                        for (const candidate of nameCandidates) {
                            const normalized = normalizeString(candidate)
                            if (normalized) {
                                resolvedName = normalized
                                break
                            }
                        }

                        let avatar: string | null = null
                        const avatarCandidates = [
                            extra?.friend_avatar,
                            extra?.friendAvatar,
                            extra?.avatar_url,
                            extra?.avatarUrl,
                        ]
                        for (const candidate of avatarCandidates) {
                            const normalized = normalizeString(candidate)
                            if (normalized) {
                                avatar = normalized
                                break
                            }
                        }

                        // 获取 friend_avatar_object_key
                        let friendAvatarObjectKey: string | null = null
                        const avatarObjectKeyCandidates = [
                            extra?.friend_avatar_object_key,
                            extra?.friendAvatarObjectKey,
                            extra?.avatar_object_key,
                            extra?.avatarObjectKey,
                        ]
                        for (const candidate of avatarObjectKeyCandidates) {
                            const normalized = normalizeString(candidate)
                            if (normalized) {
                                friendAvatarObjectKey = normalized
                                break
                            }
                        }

                        let friendRemark: string | null = null
                        if (!resolvedName && friendId && contactsMap.has(friendId)) {
                            const contact = contactsMap.get(friendId)
                            const remark = normalizeString(contact?.remark)
                            const contactName = normalizeString(contact?.name)
                            friendRemark = remark
                            resolvedName = remark || contactName || resolvedName
                            if (!avatar) {
                                avatar = normalizeString(contact?.avatar)
                            }
                            if (!friendAvatarObjectKey) {
                                friendAvatarObjectKey = normalizeString(contact?.avatarObjectKey)
                            }
                        }

                        if (!resolvedName) {
                            const segments = rawName.split('·').map((seg: string) => seg.trim()).filter((seg: string) => seg.length > 0)
                            if (segments.length > 1) {
                                const filtered = segments.filter((seg: string) => !currentNameSet.has(seg))
                                if (filtered.length > 0) {
                                    resolvedName = filtered[0]
                                } else {
                                    resolvedName = segments[segments.length - 1]
                                }
                            }
                        }

                        if (!resolvedName) {
                            resolvedName = rawName
                        }

                        return {
                            name: resolvedName,
                            friendName: resolvedName,
                            avatar,
                            remark: friendRemark,
                            friendAvatarObjectKey,
                            friendId,
                        }
                    }

                    const chatList: ChatItem[] = groups.map((group: any) => {
                        // 时间格式化函数
                        const formatTime = (timeValue: Date | string | null | undefined) => {
                            if (!timeValue) return ''
                            const now = new Date()
                            const time = timeValue instanceof Date ? timeValue : new Date(timeValue)

                            if (isNaN(time.getTime())) return ''

                            const diffMs = now.getTime() - time.getTime()
                            const diffMinutes = Math.floor(diffMs / (1000 * 60))
                            const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
                            const diffDays = Math.floor(diffHours / 24)

                            if (diffMinutes < 1) {
                                return '刚刚'
                            } else if (diffMinutes < 60) {
                                return `${diffMinutes}分钟前`
                            } else if (diffHours < 24) {
                                return time.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
                            } else if (diffDays === 1) {
                                return '昨天'
                            } else if (diffDays < 7) {
                                return `${diffDays}天前`
                            } else {
                                return time.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
                            }
                        }

                        const lastMessageTime = group.lastMessageTime instanceof Date
                            ? group.lastMessageTime
                            : new Date(group.lastMessageTime || Date.now())

                        const extra = group.extra && typeof group.extra === 'object' ? group.extra : {}
                        const isFavoriteRoom = group.type === 'favorite'

                        const isPrivateChat = group.type === 'single' || group.type === 'private'
                        const privateDisplay = isPrivateChat ? resolvePrivateChatDisplay(group) : null

                        const displayName = (isFavoriteRoom ? (normalizeString(group.name) || '收藏夹') : (privateDisplay?.name || normalizeString(group.name) || '未命名会话'))
                        const baseAvatar = privateDisplay?.avatar || normalizeString(group.avatar) || ''
                        const displayAvatar = isFavoriteRoom ? favoriteAvatar : baseAvatar
                        const groupNotice = typeof extra.description === 'string' ? extra.description : null
                        const computedGroupType = isFavoriteRoom ? 2 : (group.type === 'group' ? 1 : 0)

                        return {
                            id: group.id || group.roomId || '',
                            roomId: group.roomId || group.id || '',
                            name: displayName,
                            avatar: displayAvatar,
                            avatarLocalPath: null, // 将在后续加载时填充
                            lastMessage: group.lastMessage || '',
                            time: formatTime(lastMessageTime),
                            groupId: group.roomId || group.id || '',
                            memberCount: typeof extra.memberCount === 'number' ? extra.memberCount : null,
                            unreadCount: group.unreadCount || 0,
                            isTop: Boolean(group.isPinned),
                            isHidden: false,
                            groupType: computedGroupType,
                            lastMessageId: group.lastMessageId ?? null,
                            chatStatus: group.isMuted ? 1 : 0,
                            groupNotice,
                            showNoticeFlag: !!(groupNotice && groupNotice.trim().length > 0),
                            userAvatar: isPrivateChat ? (displayAvatar || null) : undefined,
                            friendName: privateDisplay?.friendName || null,
                            remark: privateDisplay?.remark || null,
                            extra: extra // 保留 extra 对象，包含 room_avatar_object_key 等信息
                        }
                    })

                    // 过滤掉隐藏的聊天和无效的群组ID
                    const validChatList = chatList
                        .filter(chat => !chat.isHidden && chat.groupId && chat.groupId.trim() !== '')
                        .map(chat => sanitizeChatSummaryForRuntime(state.messageRuntime, chat))

                    // 智能同步群头像缓存:
                    // 1. 优先从本地缓存读取(基于 avatar url 检查)
                    // 2. avatar url 不匹配或缓存不存在时:
                    //    - 获取临时下载地址
                    //    - 下载到本地
                    //    - 返回本地 Blob URL
                    await Promise.all(
                        validChatList.map(async (chatItem) => {
                            // 处理群聊头像
                            if (chatItem.groupType === 1) {

                                // 从 extra 中获取 room_avatar_object_key
                                const roomAvatarObjectKey = chatItem.extra?.room_avatar_object_key ||
                                    chatItem.extra?.roomAvatarObjectKey;


                                if (!roomAvatarObjectKey) {
                                    return;
                                }

                                try {
                                    // 检查本地缓存
                                    const { UserApi } = await import('../api/user')
                                    const localPath = await UserApi.syncGroupAvatarCache(
                                        chatItem.groupId,
                                        roomAvatarObjectKey,
                                        false // 不强制刷新,优先使用缓存
                                    )
                                    if (localPath) {
                                        chatItem.avatarLocalPath = localPath
                                        // 同时更新store中的对应项
                                        const storeChatItem = state.chatList.list.find(item => item.groupId === chatItem.groupId)
                                        if (storeChatItem) {
                                            storeChatItem.avatarLocalPath = localPath
                                        }
                                    }
                                } catch (error) {
                                    // 静默失败,使用默认头像
                                }
                            }
                            // 处理私聊头像
                            else if (chatItem.groupType === 0) {

                                // 从 extra 中获取 friend_avatar_object_key 和 friend_id
                                const friendAvatarObjectKey = chatItem.extra?.friend_avatar_object_key ||
                                    chatItem.extra?.friendAvatarObjectKey ||
                                    chatItem.extra?.avatar_object_key ||
                                    chatItem.extra?.avatarObjectKey;
                                const friendId = chatItem.extra?.friend_id ||
                                    chatItem.extra?.friendId ||
                                    chatItem.extra?.friend_user_id ||
                                    chatItem.extra?.friendUserId;


                                if (!friendAvatarObjectKey || !friendId) {
                                    return;
                                }

                                try {
                                    // 检查本地缓存
                                    const { UserApi } = await import('../api/user')
                                    const localPath = await UserApi.syncUserAvatarCache(
                                        friendId,
                                        friendAvatarObjectKey,
                                        false // 不强制刷新,优先使用缓存
                                    )
                                    if (localPath) {
                                        chatItem.avatarLocalPath = localPath
                                        // 同时更新store中的对应项
                                        const storeChatItem = state.chatList.list.find(item => item.roomId === chatItem.roomId)
                                        if (storeChatItem) {
                                            storeChatItem.avatarLocalPath = localPath
                                        }
                                    }
                                } catch (error) {
                                    // 静默失败,使用默认头像
                                }
                            }
                        })
                    )

                    // 根据参数选择使用同步模式还是替换模式
                    if (compareWithStore && state.chatList.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_CHAT_LIST', validChatList)
                    } else {
                        // 直接替换，用于首次加载
                        commit('SET_CHAT_LIST', validChatList)
                    }

                    // 同步更新当前账号的未读数
                    const currentAccountId = state.accounts?.currentAccountId
                    if (currentAccountId) {
                        dispatch('accounts/syncAccountUnreadCount', currentAccountId)
                    }

                    const snapshot = JSON.parse(JSON.stringify(validChatList)) as ChatItem[]
                    await saveCache(CACHE_KEYS.chatList, snapshot)

                } else {
                    commit('SET_CHAT_LIST_ERROR', response.message || '加载聊天列表失败')
                }
            } catch (error: any) {
                commit('SET_CHAT_LIST_ERROR', error.message || '网络错误，请稍后重试')
            } finally {
                if (shouldResetLoading) {
                    commit('SET_CHAT_LIST_LOADING', false)
                }
            }
        },

        // 清空聊天列表
        clearChatList({ commit }: { commit: any }) {
            commit('CLEAR_CHAT_LIST')
        },

        // 刷新聊天列表
        async refreshChatList({ dispatch }: { dispatch: any }) {
            return dispatch('loadChatList', { forceRefresh: true })
        },

        // 更新聊天项
        updateChatItem({ commit }: { commit: any }, chatItem: ChatItem) {
            commit('UPDATE_CHAT_ITEM', chatItem)
        },

        setChatUnreadCount({ commit, dispatch, state }: { commit: any; dispatch: any; state: State }, payload: { groupId: string; unreadCount: number }) {
            commit('SET_CHAT_UNREAD_COUNT', payload)

            // 同步更新当前账号的未读数
            const currentAccountId = state.accounts?.currentAccountId
            if (currentAccountId) {
                dispatch('accounts/syncAccountUnreadCount', currentAccountId)
            }
        },

        // 添加聊天项
        addChatItem({ commit }: { commit: any }, chatItem: ChatItem) {
            commit('ADD_CHAT_ITEM', chatItem)
        },

        // 删除聊天项
        removeChatItem({ commit }: { commit: any }, chatId: string) {
            commit('REMOVE_CHAT_ITEM', chatId)
        },

        // 好友申请相关 actions
        // 加载好友申请列表
        async loadFriendRequests({ commit, state }: { commit: any; state: State }, params: { forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            const { forceRefresh = false, compareWithStore = false } = params
            let shouldResetLoading = false
            try {
                commit('SET_FRIEND_REQUESTS_ERROR', null)

                if (!forceRefresh && state.friendRequests.list.length === 0) {
                    const cached = await loadCache<FriendRequest[]>(CACHE_KEYS.friendRequests)
                    if (cached?.data && Array.isArray(cached.data) && cached.data.length > 0) {
                        commit('SET_FRIEND_REQUESTS', cached.data)
                    }
                }

                const shouldShowLoading = forceRefresh || state.friendRequests.list.length === 0
                if (shouldShowLoading) {
                    commit('SET_FRIEND_REQUESTS_LOADING', true)
                    shouldResetLoading = true
                }

                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.getFriendRequests({})


                if (response.success) {
                    const formatTime = (date: Date | string | null | undefined) => {
                        if (!date) return '未知时间'
                        const time = typeof date === 'string' ? new Date(date) : date
                        if (!(time instanceof Date) || isNaN(time.getTime())) {
                            return '未知时间'
                        }

                        const now = new Date()
                        const diffMs = now.getTime() - time.getTime()
                        const diffMinutes = Math.floor(diffMs / (1000 * 60))
                        const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
                        const diffDays = Math.floor(diffHours / 24)

                        if (diffMinutes < 1) {
                            return '刚刚'
                        } else if (diffMinutes < 60) {
                            return `${diffMinutes}分钟前`
                        } else if (diffHours < 24) {
                            return `${diffHours}小时前`
                        } else if (diffDays === 1) {
                            return '昨天'
                        } else if (diffDays < 7) {
                            return `${diffDays}天前`
                        } else if (diffDays < 30) {
                            return `${Math.floor(diffDays / 7)}周前`
                        } else {
                            return time.toLocaleDateString()
                        }
                    }

                    const statusTextMap: Record<string, '待验证' | '已通过' | '已拒绝'> = {
                        pending: '待验证',
                        accepted: '已通过',
                        declined: '已拒绝'
                    }

                    const friendRequests: FriendRequest[] = Array.isArray(response.data)
                        ? response.data.map((request) => ({
                            id: request.id,
                            name: request.requester.nickname || request.requester.username,
                            avatar: request.requester.avatarUrl || undefined,
                            phone: request.requester.username,
                            status: statusTextMap[request.status] || '待验证',
                            time: formatTime(request.createdAt),
                            message: request.message || '请求添加您为好友',
                            fromUserId: request.requester.id,
                            toUserId: request.addressee.id
                        }))
                        : []


                    // 根据参数选择使用同步模式还是替换模式
                    if (compareWithStore && state.friendRequests.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_FRIEND_REQUESTS_LIST', friendRequests)
                    } else {
                        // 直接替换，用于首次加载
                        commit('SET_FRIEND_REQUESTS_LIST', friendRequests)
                    }

                    const snapshot = JSON.parse(JSON.stringify(friendRequests)) as FriendRequest[]
                    await saveCache(CACHE_KEYS.friendRequests, snapshot)

                    // 更新待处理好友申请数量
                    const pendingCount = friendRequests.filter(req => req.status === '待验证').length
                    commit('SET_PENDING_FRIEND_REQUESTS', pendingCount)

                    const currentAccountId = state.accounts?.currentAccountId
                    if (currentAccountId) {
                        commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
                            accountId: currentAccountId,
                            count: pendingCount
                        }, { root: true })
                    }
                } else {
                    // API调用失败
                    commit('SET_FRIEND_REQUESTS_ERROR', response.message || '获取好友申请失败')
                    const currentAccountId = state.accounts?.currentAccountId
                    if (currentAccountId) {
                        commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
                            accountId: currentAccountId,
                            count: 0
                        }, { root: true })
                    }

                    // 根据错误类型显示不同提示
                    if (response.message && response.message.includes('登录')) {
                        // 登录过期错误不需要在这里处理，会被全局拦截器处理
                    }
                }
            } catch (error: any) {
                commit('SET_FRIEND_REQUESTS_ERROR', error.message || '网络错误，请稍后重试')
                const currentAccountId = state.accounts?.currentAccountId
                if (currentAccountId) {
                    commit('accounts/UPDATE_FRIEND_REQUEST_COUNT', {
                        accountId: currentAccountId,
                        count: 0
                    }, { root: true })
                }
            } finally {
                if (shouldResetLoading) {
                    commit('SET_FRIEND_REQUESTS_LOADING', false)
                }
            }
        },

        // 清空好友申请列表
        clearFriendRequests({ commit }: { commit: any }) {
            commit('CLEAR_FRIEND_REQUESTS')
        },

        // 刷新好友申请列表
        async refreshFriendRequests({ dispatch }: { dispatch: any }) {
            return dispatch('loadFriendRequests', { forceRefresh: true })
        },

        // 更新好友申请项
        updateFriendRequest({ commit }: { commit: any }, friendRequest: FriendRequest) {
            commit('UPDATE_FRIEND_REQUEST', friendRequest)
        },

        // 添加好友申请项
        addFriendRequest({ commit }: { commit: any }, friendRequest: FriendRequest) {
            commit('ADD_FRIEND_REQUEST', friendRequest)
        },

        // 删除好友申请项
        removeFriendRequest({ commit }: { commit: any }, requestId: string) {
            commit('REMOVE_FRIEND_REQUEST', requestId)
        },

        // 更新当前聊天群头像
        async updateCurrentChatAvatar({ commit, state }: { commit: any; state: any }, payload: { groupId: string; avatarUrl: string }) {
            const { groupId, avatarUrl } = payload;

            // 更新当前聊天群ID对应的群聊头像
            commit('UPDATE_CURRENT_CHAT_AVATAR', { groupId, avatarUrl });

            // 同步更新聊天列表中的对应项
            const chat = state.chatList.list.find((item: any) => item.groupId === groupId);
            if (chat) {
                commit('UPDATE_CHAT_ITEM', {
                    ...chat,
                    avatar: avatarUrl,
                    avatarLocalPath: undefined // 清除本地缓存路径，等待重新下载
                });
            }

            // 强制更新界面显示
            setTimeout(() => {
                window.dispatchEvent(new CustomEvent('force-refresh-avatar', {
                    detail: { groupId, avatarUrl }
                }));
            }, 100);
        }
    },

    getters: {
        isLoggedIn: (state: State) => !!state.token,
        token: (state: State) => state.token,
        currentUser: (state: State) => state.user,
        currentTheme: (state: State) => state.theme,
        isLoading: (state: State) => state.loading,
        sidebarWidth: (state: State) => state.sidebarWidth,
        websocket: (state: State) => state.websocket,
        networkState: (state: State) => state.networkState,
        currentChatGroupId: (state: State) => state.currentChatGroupId,
        chatListScrollRequest: (state: State) => state.chatListScrollRequest,
        pendingFriendRequests: (state: State) => state.pendingFriendRequests,
        globalLoading: (state: State) => state.globalLoading,
        appVersion: (state: State) => state.version,
        latestVersionInfo: (state: State) => state.version.latest.info,
        hasAppUpdate: (state: State) => state.version.latest.hasUpdate,
        appUpdateError: (state: State) => state.version.latest.error,
        appUpdateChecking: (state: State) => state.version.latest.checking,
        messageRuntime: (state: State) => state.messageRuntime,
        isRelayOnlyMessageRuntime: (state: State) => state.messageRuntime.serverStorageMode === 'relay_only',
        isPersistMessageRuntime: (state: State) => state.messageRuntime.serverStorageMode === 'persist',
        isPlaintextAuditMode: (state: State) => state.messageRuntime.contentAuditMode === 'plaintext',
        isE2eeAuditMode: (state: State) => state.messageRuntime.contentAuditMode === 'e2ee',

        // 联系人相关 getters
        contacts: (state: State) => state.contacts.list,
        contactsLoading: (state: State) => state.contacts.loading,
        contactsError: (state: State) => state.contacts.error,
        contactsSearchKeyword: (state: State) => state.contacts.searchKeyword,
        contactsLastUpdateTime: (state: State) => state.contacts.lastUpdateTime,

        // 筛选后的联系人列表
        filteredContacts: (state: State) => {
            const keyword = state.contacts.searchKeyword.toLowerCase()
            if (!keyword) {
                return state.contacts.list
            }
            return state.contacts.list.filter(contact =>
                contact.name.toLowerCase().includes(keyword) ||
                contact.phone.includes(keyword) ||
                (contact.email && contact.email.toLowerCase().includes(keyword))
            )
        },

        // 按字母分组的联系人
        groupedContacts: (state: State, getters: any) => {
            const groups: Record<string, Contact[]> = {}

            // 如果有搜索关键词，使用本地分组逻辑
            if (state.contacts.searchKeyword) {
                getters.filteredContacts.forEach((contact: Contact) => {
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
            } else {
                // 没有搜索时，按照联系人的首字母自然分组
                state.contacts.list.forEach((contact: Contact) => {
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
            }

            return groups
        },

        // 在线联系人数量
        onlineContactsCount: (state: State) => {
            return state.contacts.list.filter(contact => contact.isOnline).length
        },

        // 最近联系人
        recentContacts: (state: State) => {
            return state.contacts.list.filter(contact => contact.isRecent)
        },

        // 聊天列表相关 getters
        chatList: (state: State) => state.chatList.list,
        chatListLoading: (state: State) => state.chatList.loading,
        chatListError: (state: State) => state.chatList.error,
        chatListLastUpdateTime: (state: State) => state.chatList.lastUpdateTime,

        // 获取未读消息总数
        totalUnreadCount: (state: State) => {
            return state.chatList.list.reduce((total, chat) => total + chat.unreadCount, 0)
        },

        // 获取置顶聊天列表
        topChatList: (state: State) => {
            return state.chatList.list.filter(chat => chat.isTop)
        },

        // 根据ID获取聊天项
        getChatById: (state: State) => (chatId: string) => {
            return state.chatList.list.find(chat => chat.id === chatId)
        },

        // 根据群组ID获取聊天项
        getChatByGroupId: (state: State) => (groupId: string) => {
            return state.chatList.list.find(chat => chat.groupId === groupId)
        },

        // 好友申请相关 getters
        friendRequests: (state: State) => state.friendRequests.list,
        friendRequestsLoading: (state: State) => state.friendRequests.loading,
        friendRequestsError: (state: State) => state.friendRequests.error,
        friendRequestsLastUpdateTime: (state: State) => state.friendRequests.lastUpdateTime,

        // 获取待处理的好友申请
        pendingFriendRequestsList: (state: State) => {
            return state.friendRequests.list.filter(request => request.status === '待验证')
        },

        // 根据ID获取好友申请
        getFriendRequestById: (state: State) => (requestId: string) => {
            return state.friendRequests.list.find(request => request.id === requestId)
        },

        // 根据发送者ID获取好友申请
        getFriendRequestByFromUserId: (state: State) => (fromUserId: string) => {
            return state.friendRequests.list.find(request => request.fromUserId === fromUserId)
        },

        // 全局用户资料相关 getters
        userProfiles: (state: State) => state.userProfiles,
        getUserProfileById: (state: State) => (userId: string | number | null | undefined) => {
            if (!userId && userId !== 0) return null
            const key = String(userId)
            return state.userProfiles[key] || null
        }
    }
})

export default store
