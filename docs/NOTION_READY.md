# RedCode IM API 文档 - Notion 导入准备

## 快速开始

### 获取 Notion 父页面 ID 的步骤：

1. 打开浏览器访问 https://notion.so
2. 选择或创建一个页面（任何页面都可以）
3. 点击页面右上角的 `···` 菜单
4. 选择「连接」/「Connections」
5. 添加「claude code mcp」集成
6. 复制页面 URL，格式如：`https://notion.so/页面名-xxxxxxxxxxxxxxxx`
7. 提取最后的 `xxxxxxxxxxxxxxxx`（32位字符），这就是页面 ID

### 页面 ID 示例：
- URL: `https://notion.so/My-Project-123abc456def789ghi`
- 页面 ID: `123abc456def789ghi`

---

## 准备导入的文档结构

### 主页面：RedCode IM API 文档

#### 子页面列表：
1. 📋 概述与认证
2. 👤 用户管理 API
3. 👥 好友系统 API
4. 💬 消息 API
5. 📖 消息已读 API
6. 🔍 消息搜索 API
7. 🏠 房间/群组 API
8. 👑 群组管理 API
9. 🔧 管理后台 API
10. 📁 文件存储 API
11. 🔄 版本管理 API
12. ⚙️ 系统设置 API
13. 🔌 WebSocket 接口

---

## 文档统计

- **总 API 端点**: 100+
- **公开路由**: 9 个
- **认证路由**: 60+ 个
- **管理员路由**: 40+ 个
- **WebSocket 事件**: 11 种

---

## 下一步

提供父页面 ID 后，我将自动：
✅ 创建主页面「RedCode IM API 文档」
✅ 创建 13 个子页面，每个对应一个模块
✅ 导入所有 API 端点详情（接口、参数、响应示例）
✅ 添加目录导航和交叉引用
