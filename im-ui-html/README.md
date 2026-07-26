# im-ui-html

纯 `HTML + CSS + JS` 的 RedCode IM UI 重构原型模块。

## 目标

- 先收敛统一的移动端视觉规范与组件封装，再承载具体 IM 页面。
- 不依赖真实 API，只用 mock 数据演示流程。
- 提供可点击、可跳转、可操作的高保真原型，作为后续正式重构基线。

## 设计方向

- **视觉主张**：Pocket Clarity，基于真实手机画布、轻表面层级和单一主强调色。
- **信息架构**：底部主导航只保留聊天 / 联系人 / 设置；聊天详情、好友申请、添加好友、群设置、搜索全部走二级页。
- **密度策略**：支持 2K / 1.5K / 1K 三档预览，对齐 Flutter 端的手机密度分档逻辑。
- **交互动效**：
  - 导航切换：轻位移 + 淡入
  - 消息进入：自下而上出现
  - 输入面板展开：短距离上浮

## 技术选型

- 单页 hash router
- 本地静态资源
- 统一 mock store
- 无 npm / bundler / framework 依赖

## 路由清单

- `#/spec`：移动端设计系统页
- `#/auth/login`：登录页
- `#/chats`：会话列表
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

1. 先看 `#/spec`，确认 tokens、组件预览、页面地图和密度策略。
2. 再看 `#/chats` -> `#/chat/c_room_launch`，确认列表页与详情页已经彻底拆开。
3. 再看 `#/contacts`、`#/contacts/requests`、`#/contacts/add`、`#/contacts/profile/u_alice`，确认联系人链路成立。
4. 再看 `#/groups/create`、`#/groups/settings/g_launch`，确认建群和群设置不再混入聊天主视图。
5. 最后看 `#/lab` 与 `#/settings`，确认扩展位和主题 / 密度调节手柄是否合理。

## 当前范围

- 已覆盖 IM 核心流程：设计系统、聊天、联系人、好友申请、建群、群设置、搜索、设置。
- 已预留扩展位：通话、AI、文件协作、自动化。
- 当前全部数据为 mock，不接真实后端。
- 主题、密度与设置开关会写入 `localStorage`，方便反复评审。
