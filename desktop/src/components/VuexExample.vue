<template>
  <div class="vuex-example">
    <h2>Vuex 状态管理示例</h2>
    
    <!-- 用户状态 -->
    <div class="user-section">
      <h3>用户状态</h3>
      <div v-if="isLoggedIn">
        <p>欢迎，{{ currentUser.username }}！</p>
        <button @click="logout">登出</button>
      </div>
      <div v-else>
        <div class="login-form">
          <input 
            v-model="username" 
            type="text" 
            placeholder="用户名"
            @keyup.enter="handleLogin"
          />
          <input 
            v-model="password" 
            type="password" 
            placeholder="密码"
            @keyup.enter="handleLogin"
          />
          <button @click="handleLogin" :disabled="isLoading">
            {{ isLoading ? '登录中...' : '登录' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 主题切换 -->
    <div class="theme-section">
      <h3>主题设置</h3>
      <p>当前主题: {{ currentTheme }}</p>
      <button @click="toggleTheme">
        切换到 {{ currentTheme === 'light' ? '深色' : '浅色' }} 主题
      </button>
    </div>

    <!-- 状态显示 -->
    <div class="state-section">
      <h3>当前状态</h3>
      <pre>{{ JSON.stringify(storeState, null, 2) }}</pre>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useStore } from 'vuex'

const store = useStore()

// 响应式数据
const username = ref('')
const password = ref('')

// 计算属性 - 从 store 获取状态
const isLoggedIn = computed(() => store.getters.isLoggedIn)
const currentUser = computed(() => store.getters.currentUser)
const currentTheme = computed(() => store.getters.currentTheme)
const isLoading = computed(() => store.getters.isLoading)
const storeState = computed(() => store.state)

// 方法
const handleLogin = async () => {
  if (!username.value || !password.value) {
    alert('请输入用户名和密码')
    return
  }

  const result = await store.dispatch('login', {
    username: username.value,
    password: password.value
  })

  if (result.success) {
    username.value = ''
    password.value = ''
  } else {
    alert('登录失败')
  }
}

const logout = () => {
  store.dispatch('logout')
}

const toggleTheme = () => {
  store.dispatch('toggleTheme')
}
</script>

<script lang="ts">
// 选项式 API 的示例（如果你更喜欢这种方式）
export default {
  name: 'VuexExample'
}
</script>

<style scoped>
.vuex-example {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
}

.user-section,
.theme-section,
.state-section {
  margin-bottom: 30px;
  padding: 20px;
  border: 1px solid #ddd;
  border-radius: 8px;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-width: 300px;
}

.login-form input,
.login-form button {
  padding: 8px 12px;
  border: 1px solid #ccc;
  border-radius: 4px;
}

.login-form button {
  background-color: #007bff;
  color: white;
  cursor: pointer;
}

.login-form button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

button {
  padding: 8px 16px;
  background-color: #28a745;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  opacity: 0.9;
}

pre {
  background-color: #f8f9fa;
  padding: 15px;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 12px;
}

h2, h3 {
  color: #333;
}
</style>
