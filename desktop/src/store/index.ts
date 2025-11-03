// @ts-nocheck
import {createStore} from 'vuex'

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
    name: string
    avatar?: string
    lastMessage: string
    time: string
    groupId: string
    memberCount?: number
    unreadCount: number
    isTop: boolean
    isHidden: boolean
    groupType: number // 0=单聊, 1=群聊
    lastMessageId?: string | null
    // groupUser相关字段，供API调用使用
    groupUserId?: number
    chatStatus?: number
    memberType?: number
    saveFlag?: number
    createUser?: number
    createTime?: string
    clearTime?: string | null
    remark?: string | null
    pushClientId?: string | null
    userName?: string | null
    friendName?: string | null
    userAvatar?: string | null
}

// 定义状态接口
export interface State {
    token: string | null,
    user: {
        id: string | null
        username: string | null
        nickname: string | null
        avatar: string | null
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
    theme: 'light' | 'dark'
    loading: boolean
    sidebarWidth: number
    websocket: WebSocket | null
    networkState: boolean
    currentChatGroupId: string | null
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
}

// 创建 store
export const store = createStore<State>({
    state: {
        token: null,
        user: {
            id: null,
            username: null,
            nickname: null,
            avatar: null,
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
        theme: 'light',
        loading: false,
        sidebarWidth: 300,
        websocket: null,
        networkState: false,
        currentChatGroupId: null,
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
        }
    },

    mutations: {
        // 授权 Token
        SET_TOKEN(state: State, token: string) {
            state.token = token
        },

        // 用户相关
        SET_USER(state: State, userInfo: { 
            id: string; 
            username: string; 
            nickname: string; 
            avatar: string; 
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
            mobile: string;
            email: string;
        }>) {
            if (userInfo.id !== undefined) state.user.id = userInfo.id
            if (userInfo.username !== undefined) state.user.username = userInfo.username
            if (userInfo.nickname !== undefined) state.user.nickname = userInfo.nickname
            if (userInfo.avatar !== undefined) state.user.avatar = userInfo.avatar
            if (userInfo.mobile !== undefined) state.user.mobile = userInfo.mobile
            if (userInfo.email !== undefined) state.user.email = userInfo.email
        },

        LOGOUT_USER(state: State) {
            state.user.id = null
            state.user.username = null
            state.user.nickname = null
            state.user.avatar = null
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

        // 设置待处理的好友申请数量
        SET_PENDING_FRIEND_REQUESTS(state: State, count: number) {
            state.pendingFriendRequests = count
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
                    console.log('🗑️ 删除不存在的联系人:', contact.name)
                }
            })

            // 2. 找出需要添加的联系人（在新数据中但不在旧数据中）
            const contactsToAdd = newContacts.filter(contact => !currentContactIds.has(contact.id))
            contactsToAdd.forEach(contact => {
                state.contacts.list.push(contact)
                console.log('➕ 添加新联系人:', contact.name)
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
                            console.log('🔄 更新联系人信息:', newContact.name)
                        }
                    }
                }
            })

            // 4. 更新最后更新时间和清除错误状态
            state.contacts.lastUpdateTime = Date.now()
            state.contacts.error = null

            console.log('✅ 联系人数据同步完成，总数:', state.contacts.list.length)
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
            state.chatList.list = chatList
            state.chatList.lastUpdateTime = Date.now()
            state.chatList.error = null
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
                    console.log('🗑️ 删除不存在的聊天:', chat.name)
                }
            })

            // 2. 找出需要添加的聊天（在新数据中但不在旧数据中）
            const chatsToAdd = newChatList.filter(chat => !currentChatIds.has(chat.id))
            chatsToAdd.forEach(chat => {
                state.chatList.list.push(chat)
                console.log('➕ 添加新聊天:', chat.name)
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
                            console.log('🔄 更新聊天信息:', newChat.name)
                        }
                    }
                }
            })

            // 4. 重新排序（置顶的在前，然后按时间倒序）
            state.chatList.list.sort((a, b) => {
                if (a.isTop && !b.isTop) return -1
                if (!a.isTop && b.isTop) return 1
                return new Date(b.time).getTime() - new Date(a.time).getTime()
            })

            // 5. 更新最后更新时间和清除错误状态
            state.chatList.lastUpdateTime = Date.now()
            state.chatList.error = null

            console.log('✅ 聊天列表数据同步完成，总数:', state.chatList.list.length)
        },

        SET_CHAT_LIST_ERROR(state: State, error: string | null) {
            state.chatList.error = error
        },

        CLEAR_CHAT_LIST(state: State) {
            state.chatList.list = []
            state.chatList.loading = false
            state.chatList.error = null
            state.chatList.lastUpdateTime = null
        },

        UPDATE_CHAT_ITEM(state: State, updatedChat: ChatItem) {
            const index = state.chatList.list.findIndex(chat => chat.id === updatedChat.id)
            if (index !== -1) {
                state.chatList.list.splice(index, 1, updatedChat)
                // 重新排序
                state.chatList.list.sort((a, b) => {
                    if (a.isTop && !b.isTop) return -1
                    if (!a.isTop && b.isTop) return 1
                    return new Date(b.time).getTime() - new Date(a.time).getTime()
                })
            }
        },

        ADD_CHAT_ITEM(state: State, newChat: ChatItem) {
            const exists = state.chatList.list.some(chat => chat.id === newChat.id)
            if (!exists) {
                state.chatList.list.push(newChat)
                // 重新排序
                state.chatList.list.sort((a, b) => {
                    if (a.isTop && !b.isTop) return -1
                    if (!a.isTop && b.isTop) return 1
                    return new Date(b.time).getTime() - new Date(a.time).getTime()
                })
            }
        },

        REMOVE_CHAT_ITEM(state: State, chatId: string) {
            state.chatList.list = state.chatList.list.filter(chat => chat.id !== chatId)
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
                    console.log('🗑️ 删除不存在的好友申请:', request.name)
                }
            })

            // 2. 找出需要添加的好友申请（在新数据中但不在旧数据中）
            const requestsToAdd = newFriendRequests.filter(request => !currentRequestIds.has(request.id))
            requestsToAdd.forEach(request => {
                state.friendRequests.list.push(request)
                console.log('➕ 添加新好友申请:', request.name)
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
                            console.log('🔄 更新好友申请信息:', newRequest.name)
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

            console.log('✅ 好友申请数据同步完成，总数:', state.friendRequests.list.length)
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
        }
    },

    actions: {
        // 登录
        async login({commit, state, getters}: { commit: any; state: any; getters: any }, loginData: {
            token: string;
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
                console.log('🔄 登录前清理残留状态...');

                // 取消所有pending的请求，避免旧请求干扰新的登录状态
                try {
                    const { cancelAllPendingRequests, setLoggingOut } = await import('../api/http');
                    cancelAllPendingRequests();
                    setLoggingOut(false); // 重置登出状态
                } catch (httpError) {
                    console.warn('清理HTTP状态失败:', httpError);
                }

                // 清理其他状态
                try {
                    commit('SET_WEBSOCKET', null);
                    commit('SET_NETWORK_STATE', false);
                    commit('SET_CURRENT_CHAT_GROUP_ID', null);
                    commit('SET_PENDING_FRIEND_REQUESTS', 0);
                } catch (commitError) {
                    console.warn('清理状态commit失败:', commitError);
                }

                // 设置token和用户信息
                console.log('🔑 准备设置token:', {
                    tokenPreview: loginData.token ? `${loginData.token.substring(0, 10)}...` : '无token',
                    userId: loginData.userInfo.id,
                    userFields: Object.keys(loginData.userInfo)
                });

                try {
                    commit('SET_TOKEN', loginData.token);
                    console.log('✅ Token设置成功');
                } catch (tokenError) {
                    console.error('❌ Token设置失败:', tokenError);
                    throw tokenError;
                }

                try {
                    commit('SET_USER', loginData.userInfo);
                    console.log('✅ 用户信息设置成功');
                } catch (userError) {
                    console.error('❌ 用户信息设置失败:', userError);
                    console.error('用户信息结构:', loginData.userInfo);
                    throw userError;
                }

                // 立即验证token是否正确设置
                const verifyToken = state.token;
                const verifyLoggedIn = getters.isLoggedIn;
                console.log('🔍 Token设置验证:', {
                    stateTokenSet: !!verifyToken,
                    stateTokenPreview: verifyToken ? `${verifyToken.substring(0, 10)}...` : '无token',
                    isLoggedIn: verifyLoggedIn,
                    tokenMatch: verifyToken === loginData.token
                });

                // 注意：不使用localStorage持久化存储
                // 因为应用需求是每次打开都要重新登录

                console.log('✅ 登录成功，状态已清理并设置');
                return { success: true, userInfo: loginData.userInfo, token: loginData.token };
            } catch (error) {
                console.error('❌ 登录action失败:', error);
                throw new Error(`登录失败: ${error instanceof Error ? error.message : '未知错误'}`);
            }
        },

        // 登出 - 显示加载蒙版，快速清除客户端状态，立即关闭WebSocket防止账户混乱
        logout({commit}: { commit: any }) {
            console.log('🔄 开始退出登录...')

            // 第一步：显示加载蒙版
            commit('SHOW_GLOBAL_LOADING', '正在退出登录...')

            // 第二步：立即设置登出状态，取消所有pending请求
            import('../api/http').then(({ setLoggingOut, cancelAllPendingRequests }) => {
                setLoggingOut(true);
                cancelAllPendingRequests();
                console.log('⚡ 所有待完成请求已取消')
            }).catch((error) => {
                console.warn('⚠️ 设置登出状态失败:', error)
            })

            // 第三步：立即关闭WebSocket连接，防止账户切换混乱
            import('../utils/websocket').then(({ webSocketManager }) => {
                webSocketManager.closeWebSocket()
                console.log('⚡ WebSocket连接已立即关闭')
            }).catch((error) => {
                console.warn('⚠️ WebSocket关闭失败:', error)
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
                    commit('LOGOUT_USER')

                    // 重置登出状态，允许用户重新登录
                    try {
                        const { setLoggingOut } = await import('../api/http')
                        setLoggingOut(false)
                        console.log('📝 已重置登出状态，允许重新登录')
                    } catch (error) {
                        console.warn('重置登出状态失败:', error)
                    }

                    // 重置窗口标题
                    try {
                        const { updateWindowTitle } = await import('../utils')
                        await updateWindowTitle() // 不传参数，显示默认标题
                    } catch (error) {
                        console.warn('重置窗口标题失败:', error)
                    }

                    console.log('✅ 认证状态已清除，将触发路由跳转')
                }

                // 设置超时保护，确保1.5秒内必须清除token
                const timeoutId = setTimeout(() => {
                    console.warn('⚠️ 登出超时，强制清除认证状态')
                    forceLogout()
                }, 1500)

                // 尝试调用服务端登出接口
                try {
                    import('../api/system').then(({ SystemApi }) => {
                        return SystemApi.logout()
                    }).then(() => {
                        console.log('✅ 服务器端登出成功')
                    }).catch((error) => {
                        console.warn('⚠️ 服务器端登出失败:', error)
                    }).finally(() => {
                        // 清除超时定时器
                        clearTimeout(timeoutId)
                        // 清除认证状态
                        forceLogout()
                    })
                } catch (error) {
                    console.warn('⚠️ 无法加载API模块:', error)
                    // 清除超时定时器
                    clearTimeout(timeoutId)
                    // 立即清除认证状态
                    forceLogout()
                }

                console.log('✅ 后台清理已启动，等待完成...')
            }, 300) // 给用户一点反馈时间

            console.log('✅ WebSocket已关闭，正在处理后台清理...')
        },

        // 切换主题
        toggleTheme({commit, state}: { commit: any; state: State }) {
            const newTheme = state.theme === 'light' ? 'dark' : 'light'
            commit('SET_THEME', newTheme)
        },

        // 设置侧边栏宽度
        setSidebarWidth({commit}: { commit: any }, width: number) {
            commit('SET_SIDEBAR_WIDTH', width)
        },

        // 更新待处理的好友申请数量
        async updatePendingFriendRequests({commit}: { commit: any }) {
            try {
                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.unHandleFriendApply()
                
                if (response.success && response.data !== undefined) {
                    // 根据API返回的数据类型判断
                    let count = 0
                    if (typeof response.data === 'number') {
                        // 如果直接返回数量
                        count = response.data
                    } else if (Array.isArray(response.data)) {
                        // 如果返回数组，取数组长度
                        count = response.data.length
                    }
                    commit('SET_PENDING_FRIEND_REQUESTS', count)
                    console.log('✅ 更新待处理好友申请数量:', count)
                } else {
                    // 如果API调用失败，使用默认值0
                    commit('SET_PENDING_FRIEND_REQUESTS', 0)
                    console.warn('⚠️ API调用失败，设置好友申请数量为0')
                }
            } catch (error) {
                console.error('❌ 获取好友申请数量失败:', error)
                // 如果发生错误，使用默认值0
                commit('SET_PENDING_FRIEND_REQUESTS', 0)
            }
        },

        // 显示全局加载
        showGlobalLoading({commit}: { commit: any }, text: string = '加载中...') {
            commit('SHOW_GLOBAL_LOADING', text)
        },

        // 隐藏全局加载
        hideGlobalLoading({commit}: { commit: any }) {
            commit('HIDE_GLOBAL_LOADING')
        },

        // 更新全局加载文字
        updateGlobalLoadingText({commit}: { commit: any }, text: string) {
            commit('SET_GLOBAL_LOADING_TEXT', text)
        },

        // 加载联系人列表
        async loadContacts({commit, state}: { commit: any; state: State }, params: { keyword?: string; forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            try {
                commit('SET_CONTACTS_LOADING', true)
                commit('SET_CONTACTS_ERROR', null)

                // 如果不强制刷新且store中已有数据，直接返回
                if (!params.forceRefresh && state.contacts.list.length > 0 && !params.keyword) {
                    console.log('✅ 直接使用store中的联系人数据:', state.contacts.list.length, '个联系人')
                    return
                }

                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.getMyFriendList({
                    keyword: params.keyword || '',
                    page: 1,
                    size: 1000 // 获取所有联系人
                })

                if (response.success && response.data) {
                    // 根据新的API响应结构处理数据
                    const apiData = response.data
                    const contacts: Contact[] = []

                    // 检查数据结构
                    if (apiData.myFriendList && Array.isArray(apiData.myFriendList)) {
                        // 遍历每个字母分组
                        apiData.myFriendList.forEach((group: any) => {
                            if (group.friends && Array.isArray(group.friends)) {
                                // 遍历该分组下的好友
                                group.friends.forEach((friend: any) => {
                                    contacts.push({
                                        id: friend.friendId?.toString() || friend.id?.toString() || '',
                                        name: friend.friendName || friend.realName || friend.userName || `用户${friend.friendId || friend.id}`,
                                        avatar: friend.avatar || '', // API响应中可能没有头像字段
                                        phone: friend.friendMobile || friend.mobile || '',
                                        email: friend.email || '',
                                        isOnline: Math.random() > 0.5, // 临时随机状态，后续可接入真实在线状态
                                        lastSeen: formatLastSeen(friend.createTime),
                                        isRecent: isRecentContact(friend.createTime),
                                        remark: friend.friendName || friend.realName,
                                        status: friend.status || 1,
                                        createTime: friend.createTime,
                                        updateTime: friend.updateTime || friend.createTime
                                    })
                                })
                            }
                        })
                    }

                    // 根据参数选择使用同步模式还是替换模式
                    if (params.compareWithStore && state.contacts.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_CONTACTS_LIST', contacts)
                        console.log('🔄 使用智能同步模式更新联系人列表')
                    } else {
                        // 直接替换，用于首次加载或搜索
                        commit('SET_CONTACTS_LIST', contacts)
                        console.log('📝 使用替换模式设置联系人列表')
                    }

                    if (params.keyword) {
                        commit('SET_CONTACTS_SEARCH_KEYWORD', params.keyword)
                    }

                    console.log('✅ 联系人列表加载成功:', contacts.length, '个联系人')
                    console.log('📊 API返回的分组索引:', apiData.myFriendsIndexList)
                } else {
                    commit('SET_CONTACTS_ERROR', response.message || '加载联系人列表失败')
                    console.warn('❌ 联系人列表API调用失败:', response.message)
                }
            } catch (error: any) {
                console.error('❌ 加载联系人列表异常:', error)
                commit('SET_CONTACTS_ERROR', error.message || '网络错误，请稍后重试')
            } finally {
                commit('SET_CONTACTS_LOADING', false)
            }
        },

        // 搜索联系人
        async searchContacts({dispatch}: { dispatch: any }, keyword: string) {
            return dispatch('loadContacts', { keyword, forceRefresh: true })
        },

        // 清空联系人列表
        clearContacts({commit}: { commit: any }) {
            commit('CLEAR_CONTACTS')
        },

        // 刷新联系人列表
        async refreshContacts({dispatch}: { dispatch: any }) {
            return dispatch('loadContacts', { forceRefresh: true })
        },

        // 聊天列表相关 actions
        // 加载聊天列表
        async loadChatList({commit, state}: { commit: any; state: State }, params: { forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            try {
                // 如果不强制刷新且store中已有数据，直接返回，不设置loading状态
                if (!params.forceRefresh && state.chatList.list.length > 0) {
                    console.log('✅ 直接使用store中的聊天列表数据:', state.chatList.list.length, '个聊天')
                    return
                }

                // 只有在真正需要加载数据时才设置loading状态
                // 如果是后台刷新（有缓存数据的情况下），不显示loading
                const shouldShowLoading = state.chatList.list.length === 0
                if (shouldShowLoading) {
                    commit('SET_CHAT_LIST_LOADING', true)
                }

                commit('SET_CHAT_LIST_ERROR', null)

                // 导入 GroupApi 并调用 API
                const { GroupApi } = await import('../api/group')
                const response = await GroupApi.getMyChatGroupList({
                    page: 1,
                    size: 100
                })

                if (response.success && response.data) {
                    const groups = response.data
                    console.log('🔍 API响应的原始群组数据:', groups)

                    const chatList: ChatItem[] = groups.map((group: any) => {
                        // 时间格式化函数
                        const formatTime = (timeStr: string) => {
                            if (!timeStr) return ''

                            const now = new Date()
                            const time = new Date(timeStr)

                            if (isNaN(time.getTime())) return timeStr

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

                        return {
                            // 使用真实的三对象结构数据
                            id: group.imGroup?.groupId || '',
                            name: group.imGroup?.groupName || '未知群聊',
                            avatar: group.imGroup?.groupAvatar || '',
                            lastMessage: group.imGroupMessageRef?.lastMsgContent || '暂无消息',
                            time: formatTime(group.imGroupMessageRef?.createTime),
                            groupId: group.imGroup?.groupId || '',
                            memberCount: group.imGroup?.maxMemberCount || 0,
                            // 新增字段：使用真实的用户设置数据
                            unreadCount: group.groupUser?.unReadNum || 0,
                            isTop: group.groupUser?.topFlag === 1,
                            isHidden: group.groupUser?.hiddenFlag === 1,
                            groupType: group.imGroup?.groupType || 0,
                            lastMessageId: group.imGroupMessageRef?.msgId || null,
                            // 保存完整的groupUser数据供后续API调用使用
                            groupUserId: group.groupUser?.id,
                            chatStatus: group.groupUser?.chatStatus,
                            memberType: group.groupUser?.memberType,
                            saveFlag: group.groupUser?.saveFlag,
                            createUser: group.groupUser?.createUser,
                            createTime: group.groupUser?.createTime,
                            clearTime: group.groupUser?.clearTime,
                            remark: group.groupUser?.remark,
                            pushClientId: group.groupUser?.pushClientId,
                            userName: group.groupUser?.userName,
                            friendName: group.groupUser?.friendName,
                            userAvatar: group.groupUser?.userAvatar
                        }
                    })

                    // 过滤掉隐藏的聊天和无效的群组ID
                    const validChatList = chatList.filter(chat => !chat.isHidden && chat.groupId && chat.groupId.trim() !== '')

                    // 根据参数选择使用同步模式还是替换模式
                    if (params.compareWithStore && state.chatList.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_CHAT_LIST', validChatList)
                        console.log('🔄 使用智能同步模式更新聊天列表')
                    } else {
                        // 直接替换，用于首次加载
                        commit('SET_CHAT_LIST', validChatList)
                        console.log('📝 使用替换模式设置聊天列表')
                    }

                    console.log('✅ 聊天列表加载成功:', validChatList.length, '个聊天')
                } else {
                    commit('SET_CHAT_LIST_ERROR', response.message || '加载聊天列表失败')
                    console.warn('❌ 聊天列表API调用失败:', response.message)
                }
            } catch (error: any) {
                console.error('❌ 加载聊天列表异常:', error)
                commit('SET_CHAT_LIST_ERROR', error.message || '网络错误，请稍后重试')
            } finally {
                commit('SET_CHAT_LIST_LOADING', false)
            }
        },

        // 清空聊天列表
        clearChatList({commit}: { commit: any }) {
            commit('CLEAR_CHAT_LIST')
        },

        // 刷新聊天列表
        async refreshChatList({dispatch}: { dispatch: any }) {
            return dispatch('loadChatList', { forceRefresh: true })
        },

        // 更新聊天项
        updateChatItem({commit}: { commit: any }, chatItem: ChatItem) {
            commit('UPDATE_CHAT_ITEM', chatItem)
        },

        // 添加聊天项
        addChatItem({commit}: { commit: any }, chatItem: ChatItem) {
            commit('ADD_CHAT_ITEM', chatItem)
        },

        // 删除聊天项
        removeChatItem({commit}: { commit: any }, chatId: string) {
            commit('REMOVE_CHAT_ITEM', chatId)
        },

        // 好友申请相关 actions
        // 加载好友申请列表
        async loadFriendRequests({commit, state}: { commit: any; state: State }, params: { forceRefresh?: boolean; compareWithStore?: boolean } = {}) {
            try {
                // 如果不强制刷新且store中已有数据，直接返回，不设置loading状态
                if (!params.forceRefresh && state.friendRequests.list.length > 0) {
                    console.log('✅ 直接使用store中的好友申请数据:', state.friendRequests.list.length, '个申请')
                    return
                }

                // 只有在真正需要加载数据时才设置loading状态
                // 如果是后台刷新（有缓存数据的情况下），不显示loading
                const shouldShowLoading = state.friendRequests.list.length === 0
                if (shouldShowLoading) {
                    commit('SET_FRIEND_REQUESTS_LOADING', true)
                }

                commit('SET_FRIEND_REQUESTS_ERROR', null)

                // 导入 FriendApi 并调用 API
                const { FriendApi } = await import('../api/friend')
                const response = await FriendApi.checkFriendApply({})

                console.log('好友申请API响应:', response)

                // 检查响应状态
                if (response.success) {
                    let friendRequests: FriendRequest[] = []

                    if (response.data && Array.isArray(response.data) && response.data.length > 0) {
                        // 转换 API 数据为组件所需格式
                        friendRequests = response.data.map((apply: any): FriendRequest => {
                            // 状态映射：根据bear-chat-uniapp的实现
                            const statusMap: Record<number, '待验证' | '已通过' | '已拒绝'> = {
                                0: '待验证',
                                1: '已通过',
                                2: '已拒绝'
                            }

                            // 格式化时间
                            const formatTime = (createTime: string | number) => {
                                if (!createTime) return '未知时间'

                                const now = new Date()
                                const time = new Date(createTime)

                                // 检查时间是否有效
                                if (isNaN(time.getTime())) return '未知时间'

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

                            const applyData = apply as any

                            return {
                                id: applyData.id || applyData.applyId || String(Date.now()),
                                name: applyData.userName || applyData.nickname || applyData.realName || `用户${applyData.fromUserId || applyData.id}`,
                                avatar: applyData.avatar || applyData.userAvatar,
                                phone: applyData.mobile || applyData.phone,
                                status: statusMap[applyData.status] || '待验证',
                                time: formatTime(applyData.createTime || applyData.addTime),
                                message: applyData.message || applyData.description || applyData.applyMessage || '请求添加您为好友',
                                fromUserId: applyData.fromUserId || applyData.userId,
                                toUserId: applyData.toUserId
                            }
                        })

                        console.log('✅ 加载好友申请成功:', friendRequests.length, '条申请')
                    } else {
                        // 成功但无数据
                        friendRequests = []
                        console.log('✅ 好友申请加载成功，暂无申请记录')
                    }

                    // 根据参数选择使用同步模式还是替换模式
                    if (params.compareWithStore && state.friendRequests.list.length > 0) {
                        // 使用智能同步，避免列表闪烁
                        commit('SYNC_FRIEND_REQUESTS_LIST', friendRequests)
                        console.log('🔄 使用智能同步模式更新好友申请列表')
                    } else {
                        // 直接替换，用于首次加载
                        commit('SET_FRIEND_REQUESTS_LIST', friendRequests)
                        console.log('📝 使用替换模式设置好友申请列表')
                    }

                    // 更新待处理好友申请数量
                    const pendingCount = friendRequests.filter(req => req.status === '待验证').length
                    commit('SET_PENDING_FRIEND_REQUESTS', pendingCount)
                } else {
                    // API调用失败
                    console.warn('❌ 好友申请API调用失败:', response.message)
                    commit('SET_FRIEND_REQUESTS_ERROR', response.message || '获取好友申请失败')

                    // 根据错误类型显示不同提示
                    if (response.message && response.message.includes('登录')) {
                        // 登录过期错误不需要在这里处理，会被全局拦截器处理
                    }
                }
            } catch (error: any) {
                console.error('❌ 加载好友申请异常:', error)
                commit('SET_FRIEND_REQUESTS_ERROR', error.message || '网络错误，请稍后重试')
            } finally {
                commit('SET_FRIEND_REQUESTS_LOADING', false)
            }
        },

        // 清空好友申请列表
        clearFriendRequests({commit}: { commit: any }) {
            commit('CLEAR_FRIEND_REQUESTS')
        },

        // 刷新好友申请列表
        async refreshFriendRequests({dispatch}: { dispatch: any }) {
            return dispatch('loadFriendRequests', { forceRefresh: true })
        },

        // 更新好友申请项
        updateFriendRequest({commit}: { commit: any }, friendRequest: FriendRequest) {
            commit('UPDATE_FRIEND_REQUEST', friendRequest)
        },

        // 添加好友申请项
        addFriendRequest({commit}: { commit: any }, friendRequest: FriendRequest) {
            commit('ADD_FRIEND_REQUEST', friendRequest)
        },

        // 删除好友申请项
        removeFriendRequest({commit}: { commit: any }, requestId: string) {
            commit('REMOVE_FRIEND_REQUEST', requestId)
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
        pendingFriendRequests: (state: State) => state.pendingFriendRequests,
        globalLoading: (state: State) => state.globalLoading,
        
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
        }
    }
})

export default store
