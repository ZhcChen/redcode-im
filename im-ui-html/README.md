# im-ui-html

纯 `HTML + CSS + JS` 的 RedCode IM UI 重构原型模块。

## 目标

- 先收敛统一的视觉规范，再承载具体 IM 页面。
- 不依赖真实 API，只用 mock 数据演示流程。
- 提供可点击、可跳转、可操作的高保真原型，作为后续正式重构基线。

## 设计方向

- **视觉主张**：Graphite Command Lounge，冷静深色工作台 + 单一青蓝高亮。
- **内容结构**：规范页 -> 登录 -> 会话/聊天 -> 联系人/申请 -> 建群/群设置 -> 搜索 -> 扩展 -> 设置。
- **交互动效**：
  - 导航切换：轻位移 + 淡入
  - 消息进入：自下而上出现
  - 弹层/侧栏：短距离滑入

## 技术选型

- 单页 hash router
- 本地静态资源
- 统一 mock store
- 无 npm / bundler / framework 依赖

## 路由清单

- `#/spec`：设计规范页
- `#/auth/login`：登录页
- `#/chats`：会话主视图
- `#/chat/:chatId`：聊天详情
- `#/contacts`：联系人
- `#/contacts/requests`：好友申请
- `#/contacts/add`：添加好友
- `#/contacts/profile/:contactId`：联系人详情
- `#/groups`：群组概览
- `#/groups/create`：创建群聊
- `#/groups/settings/:groupId`：群设置
- `#/search`：消息搜索
- `#/lab`：扩展总览
- `#/lab/:moduleId`：扩展详情
- `#/settings`：设置

## 启动方式

### 方式 1：直接打开

直接打开 `im-ui-html/index.html` 即可。

### 方式 2：本地静态服务

```bash
cd im-ui-html
python3 -m http.server 8020
```

然后访问：

```text
http://127.0.0.1:8020/#/spec
```

## 推荐评审路径

1. 先看 `#/spec`，确认颜色、层级、组件和动效方向。
2. 再看 `#/chat/c_room_launch`，确认三栏聊天工作区是否成立。
3. 再看 `#/contacts`、`#/contacts/add`、`#/groups/create`，确认社交流程是否顺。
4. 最后看 `#/lab` 与 `#/settings`，确认未来扩展位和主题能力是否合理。

## 当前范围

- 已覆盖 IM 核心流程：聊天、联系人、好友申请、建群、群设置、搜索、设置。
- 已预留扩展位：通话、AI、文件协作、自动化。
- 当前全部数据为 mock，不接真实后端。
