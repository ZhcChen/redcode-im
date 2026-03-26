# RedCode IM 多语言架构设计

## 1. 背景

当前项目需要为以下模块补齐多语言能力：

- `backend`
- `admin`
- `frontend`
- `desktop`

现状并不一致：

- `admin` 已接入 `vue-i18n`，但覆盖不完整，仍有较多硬编码文案。
- `frontend` 尚未建立 Flutter 官方多语言基础设施。
- `desktop` 尚未接入 `vue-i18n`，且组件层与非组件层均存在较多硬编码文案。
- `backend` 存在统一错误出口，但业务错误与提示文案大量散落在 handler/service 中，尚未结构化。

本设计的目标不是简单替换中文字符串，而是建立一套跨 `backend/admin/frontend/desktop` 的稳定消息协议与语言回退机制。

## 2. 目标与非目标

### 2.1 目标

- 首批支持 `zh-CN` 与 `en-US`
- `backend` 根据请求头 `Accept-Language` 返回本地化 `message`
- API 响应始终返回稳定的 `code + message_key + message`
- 语言包缺项时，`message` 回退为 `message_key`
- `admin`、`frontend`、`desktop` 均具备本地 UI 文案翻译能力
- 三端统一采用“API `message` 优先，本地 `message_key` 兜底”的展示策略

### 2.2 非目标

- 不处理用户生成内容的翻译
- 不在本轮引入机器翻译或第三方在线翻译服务
- 不要求首轮完成所有页面与所有业务域的 100% 覆盖

## 3. 核心设计结论

### 3.1 双层多语言模型

本次采用“双层模型”：

- `backend` 负责 API 语义文案
  - 错误信息
  - 校验失败
  - 业务提示
  - 部分成功提示
- 三端负责客户端自身文案
  - 页面标题
  - 按钮/表单/占位符
  - 空状态
  - 本地交互提示
  - 离线或纯前端生成提示

### 3.2 统一消息协议

推荐所有 API 错误/提示响应统一包含以下字段：

```json
{
  "code": "VALIDATION_ERROR",
  "message_key": "auth.invalid_verify_code",
  "message": "验证码错误",
  "message_params": null,
  "details": null
}
```

字段约束：

- `code`：稳定业务/错误码
- `message_key`：稳定消息键，用于测试断言、本地兜底与跨端对齐
- `message`：根据请求语言渲染后的最终文案
- `message_params`：插值参数，便于本地二次翻译时复用
- `details`：保留结构化上下文，不承载最终展示文案

### 3.3 语言回退链

`backend` 统一采用以下回退链：

1. 精确命中，如 `zh-CN`
2. 语言族命中，如 `zh`
3. 默认语言 `zh-CN`
4. 最终回退为 `message_key`

三端展示时统一采用以下优先级：

1. 优先展示 API 返回的 `message`
2. 若 `message == message_key`，尝试用本地语言包按 `message_key + message_params` 再翻译一次
3. 若本地也缺项，则原样显示 `message_key` 或统一展示兜底错误

## 4. Key 规范

### 4.1 命名规则

统一采用“领域.场景.语义”的点分风格，全部小写，例如：

- `common.network_error`
- `common.unknown_error`
- `auth.invalid_verify_code`
- `auth.token_expired`
- `user.not_found`
- `friend.already_added`
- `message.send_failed`
- `group.member_limit_exceeded`
- `admin.report.not_found`

### 4.2 约束

- `message_key` 一旦对外暴露，即视为协议字段管理
- 文案允许调整，`message_key` 尽量只增不改
- 不使用无语义编号型 key，例如 `error_001`
- 不将最终文案直接作为 key
- 不在业务层预拼接字符串，统一使用插值参数

### 4.3 插值

示例：

- key: `group.member_count_limit`
- `zh-CN`: `群成员数量不能超过 {max}`
- `en-US`: `Group member count cannot exceed {max}`

推荐响应形态：

```json
{
  "code": "VALIDATION_ERROR",
  "message_key": "group.member_count_limit",
  "message": "群成员数量不能超过 500",
  "message_params": {
    "max": 500
  }
}
```

## 5. 模块级落地方案

### 5.1 backend

以 [backend/src/error.rs](/Users/chen/code/redcode-im/backend/src/error.rs) 为切入点，建立正式 i18n 基础设施，而不是继续在 handler/service 内部直接构造最终字符串。

建议新增以下抽象：

- `Locale`
  - 负责解析 `Accept-Language`
  - 统一内部语言标识
- `MessageDescriptor`
  - 包含 `message_key`
  - 包含 `message_params`
  - 可选 `fallback_message`
- `MessageCatalog`
  - 负责启动时加载语言包并驻留内存
- `Localizer`
  - 负责根据 `locale + key + params` 生成最终 `message`

推荐请求链路：

1. middleware 解析 `Accept-Language`
2. 将语言信息放入 request context
3. `IntoResponse for AppError` 在统一出口读取语言上下文
4. 使用 `MessageCatalog` 生成最终 `message`

业务层不再写：

```rust
AppError::ValidationError("验证码错误".to_string())
```

而改为结构化表达，例如：

```rust
AppError::validation("auth.invalid_verify_code")
```

或：

```rust
AppError::validation_with_params(
    "group.member_count_limit",
    json!({ "max": 500 })
)
```

### 5.2 admin

继续沿用现有 `vue-i18n` 基础，重点补齐覆盖率与清理漏网硬编码。

建议结构：

- `admin/src/locale/common/`
- `admin/src/locale/modules/`
- `admin/src/views/**/locale/`

策略：

- 本地 UI 文案继续走 `vue-i18n`
- API 返回的 `message` 直接展示
- 若后端回退为 `message_key`，则可本地二次翻译

### 5.3 frontend

建议采用 Flutter 官方 `gen_l10n`：

- `frontend/lib/l10n/app_zh.arb`
- `frontend/lib/l10n/app_en.arb`

需要在 `MaterialApp` 层补齐：

- `locale`
- `supportedLocales`
- `localizationsDelegates`

范围不仅限于页面层，还包括：

- `service`
- `repository`
- 通用组件
- 本地异常文案

### 5.4 desktop

建议引入 `vue-i18n`，新增：

- `desktop/src/locales/zh-CN/*.json`
- `desktop/src/locales/en-US/*.json`
- `desktop/src/i18n/index.ts`

由于当前文案不仅分布在组件中，也分布在 `store`、`api`、`utils`，因此需要提供组件层与非组件层都可访问的统一 `t()` 能力。

## 6. 目录结构建议

### 6.1 backend

建议按业务域拆分语言包：

- `backend/i18n/zh-CN/common.json`
- `backend/i18n/zh-CN/auth.json`
- `backend/i18n/zh-CN/user.json`
- `backend/i18n/zh-CN/friend.json`
- `backend/i18n/zh-CN/message.json`
- `backend/i18n/zh-CN/group.json`
- `backend/i18n/en-US/common.json`
- `backend/i18n/en-US/auth.json`
- `backend/i18n/en-US/user.json`
- `backend/i18n/en-US/friend.json`
- `backend/i18n/en-US/message.json`
- `backend/i18n/en-US/group.json`

### 6.2 admin

- `admin/src/locale/common/`
- `admin/src/locale/modules/`
- `admin/src/views/**/locale/`

### 6.3 frontend

- `frontend/lib/l10n/app_zh.arb`
- `frontend/lib/l10n/app_en.arb`

### 6.4 desktop

- `desktop/src/locales/zh-CN/*.json`
- `desktop/src/locales/en-US/*.json`
- `desktop/src/i18n/index.ts`

## 7. 实施顺序

推荐按以下顺序推进：

1. 固定语言集合、消息协议、回退规则
2. `backend` 建立 i18n 基础设施
3. `backend` 优先迁移高频错误域
   - `common`
   - `auth`
   - `user`
   - `friend`
   - `message`
   - `group`
4. `admin` 补齐现有 `vue-i18n`
5. `frontend` 建立 Flutter i18n 基础设施
6. `desktop` 建立 `vue-i18n`
7. 三端统一接入 API `message` 优先、本地 `message_key` 兜底
8. 扫尾清理遗留硬编码文案

先定 `backend` 协议，再做三端接入，可以避免三端出现三套不同错误展示逻辑。

## 8. 测试策略

### 8.1 backend

重点测试四类能力：

1. `Accept-Language` 解析
2. `zh-CN` / `en-US` 命中
3. 不支持语言时的回退链
4. `message_key + params` 插值与缺失翻译回退

同时需要补齐协议测试，确保响应固定包含：

- `code`
- `message_key`
- `message`

并为代表性业务域补集成测试：

- `auth`
- `user`
- `friend`
- `message`
- `group`

### 8.2 admin / frontend / desktop

共同测试目标：

- 初始化是否正确
- 本地 UI 文案能否切换语言
- API 返回 `message_key` 时的本地兜底能否工作

其中：

- `admin` 重点验证现有页面的半迁移问题
- `frontend` 重点验证 `MaterialApp` 语言接线与 `gen_l10n`
- `desktop` 重点验证组件层与非组件层共享 `t()` 能力

## 9. 验收标准

最小验收线如下：

- 首批仅支持 `zh-CN` / `en-US`
- `backend` 接入后的错误响应始终返回 `code + message_key + message`
- 同一接口在不同 `Accept-Language` 下返回不同语言的 `message`
- 语言包缺项时，`message` 回退为 `message_key`
- 三端均具备本地 UI 文案翻译能力
- 三端展示 API 错误时，优先使用 `message`，并支持 `message_key` 本地兜底
- 迁移范围内不再新增新的用户可见硬编码中文/英文字符串

迁移期优先覆盖高频路径：

- 登录
- 会话列表
- 联系人
- 群组
- 消息发送与失败提示
- 管理后台核心列表页

## 10. 风险与控制措施

### 10.1 风险

- `backend` 业务文案散落严重，不能只改一个统一错误出口
- `admin` 已处于半迁移状态，容易出现同页混用
- `frontend` 与 `desktop` 的非 UI 层同样存在大量硬编码文案
- 后端与三端 `message_key` 容易漂移
- 测试若只断言最终文案，容易脆弱失败

### 10.2 控制措施

- 在迁移前先冻结 `message_key` 命名规范
- 先做 `backend` 协议层，再做三端消费层
- 每迁移一个业务域，同步补齐两份语言包
- 测试优先断言 `code/message_key`
- 通过硬编码扫描生成迁移清单，避免边改边找

## 11. 结论

本次多语言改造的关键不是简单接入翻译库，而是建立一套稳定的跨端消息协议：

- `backend` 负责按请求语言返回最终 `message`
- API 同时返回稳定的 `message_key`
- 三端统一消费 `message`，并在必要时用 `message_key` 做本地兜底

在此基础上，`admin` 做补齐，`frontend` 与 `desktop` 从零建基础设施，`backend` 则负责把现有散落文案逐步收口为结构化消息系统。
