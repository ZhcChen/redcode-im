# Vuex 状态管理

本项目已集成 Vuex 4 状态管理库，适用于 Vue 3 项目。

## 文件结构

```
src/store/
├── index.ts      # 主要的 store 配置
├── types.ts      # TypeScript 类型声明
└── README.md     # 使用说明
```

## 使用方法

### 1. 在组件中使用 Vuex

#### 组合式 API (推荐)

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { useStore } from 'vuex'
import type { State } from '../store'

const store = useStore<State>()

// 获取状态
const isLoggedIn = computed(() => store.getters.isLoggedIn)
const currentUser = computed(() => store.getters.currentUser)

// 调用 actions
const login = async (credentials) => {
  await store.dispatch('login', credentials)
}

// 直接提交 mutations (不推荐，建议使用 actions)
const logout = () => {
  store.commit('LOGOUT_USER')
}
</script>
```

#### 选项式 API

```vue
<script>
export default {
  computed: {
    isLoggedIn() {
      return this.$store.getters.isLoggedIn
    },
    currentUser() {
      return this.$store.getters.currentUser
    }
  },
  methods: {
    async login(credentials) {
      await this.$store.dispatch('login', credentials)
    },
    logout() {
      this.$store.dispatch('logout')
    }
  }
}
</script>
```

### 2. 当前可用的状态

- `user`: 用户信息 (id, username, isLoggedIn)
- `theme`: 主题设置 ('light' | 'dark')
- `loading`: 加载状态

### 3. 可用的 Getters

- `isLoggedIn`: 用户是否已登录
- `currentUser`: 当前用户信息
- `currentTheme`: 当前主题
- `isLoading`: 是否正在加载

### 4. 可用的 Actions

- `login(credentials)`: 用户登录
- `logout()`: 用户登出
- `toggleTheme()`: 切换主题

### 5. 示例页面

访问 `/vuex-example` 路由可以看到完整的使用示例。

## 扩展 Store

如果需要添加新的状态或功能，可以：

1. 在 `State` 接口中添加新的状态字段
2. 在 `state` 中添加初始值
3. 添加相应的 `mutations`、`actions` 和 `getters`

例如：

```typescript
// 添加新状态
export interface State {
  // ... 现有状态
  notifications: Notification[]
}

// 添加 mutations
mutations: {
  // ... 现有 mutations
  ADD_NOTIFICATION(state, notification: Notification) {
    state.notifications.push(notification)
  }
}

// 添加 actions
actions: {
  // ... 现有 actions
  async fetchNotifications({ commit }) {
    const notifications = await api.getNotifications()
    commit('SET_NOTIFICATIONS', notifications)
  }
}
```
