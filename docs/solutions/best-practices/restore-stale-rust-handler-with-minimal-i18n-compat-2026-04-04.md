---
title: 恢复旧 Rust handler 改动时优先补最小 i18n 兼容层
date: 2026-04-04
category: best-practices
module: backend-message-handler
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - 从旧分支或 backup 快照恢复 Rust handler 文件到当前 main
  - 恢复文件里包含 message_key 或 i18n helper 调用，但仓库当前错误模型尚未完全接入
  - cargo test 因缺失辅助函数、类型或 error 方法而无法编译
  - 目标是先保持主分支可编译，而不是顺手完成整套 i18n 基建
symptoms:
  - cargo test 报 parse_message_sender_id、message_validation_error 等符号不存在
  - AppError::with_message_key 或 MessageParams 在当前主分支里并不存在
  - 恢复文件包含新调用点，但依赖的 error/i18n 基础设施没有同时落地
root_cause: incomplete_setup
resolution_type: code_fix
tags:
  - rust-backend
  - i18n-compat
  - stale-restore
  - cargo-test
  - message-handler
---

# 恢复旧 Rust handler 改动时优先补最小 i18n 兼容层

## Context

这次从 backup 快照恢复 `backend/src/handlers/message.rs` 时，文件本身已经切到了 `message_key` 风格：开始调用 `parse_message_sender_id`、`message_forbidden_error`、`message_validation_error_with_params`，并尝试使用 `with_message_key` / `MessageParams` 这一类抽象。但当前主分支的 `AppError` 结构并没有同步完成那套 i18n error 基建，直接恢复后 `cargo test` 立刻编译失败。

这类情况的关键不是“把旧文件原样拿回来”，而是判断：当前任务是恢复有效改动，还是继续扩散未收口的基础设施。如果目标是让主分支恢复可编译，就应该优先做 **最小兼容补齐**，而不是顺手把整套 i18n error 协议在一次恢复里硬接完。

## Guidance

推荐按下面的原则处理：

1. **先把编译失败归类成“调用点超前”，不是“当前主分支错了”**
   - 先跑 `cargo test`
   - 看报错是否集中在：
     - helper 函数不存在
     - 类型别名不存在
     - `AppError` 上的方法不存在
   - 如果是，就说明恢复文件比当前主分支的基础设施更“新”

2. **优先在当前文件内补最小兼容层**
   - 例如在 `message.rs` 内增加：
     - `type MessageParams = HashMap<String, String>;`
     - `parse_message_sender_id`
     - `message_forbidden_error`
     - `message_validation_error`
     - `message_validation_error_with_params`
     - `message_internal_error`
     - `message_not_found_error`
   - 这些 helper 的职责不是建立完整 i18n 系统，而是把新调用点降落到当前 `AppError` 能理解的字符串错误上

3. **不要为了恢复一个文件，同时改造全局 error 模型**
   - 如果当前 `AppError` 没有 `with_message_key`
   - 如果统一的 `message_key/message_params` 协议还没在 backend 全量接入
   - 那就不要在这次恢复里顺便扩展 `backend/src/error.rs`
   - 否则很容易把“恢复旧工作区”膨胀成“做一半新的 i18n 基建”

4. **用现有中文文案做稳定降级**
   - 在 helper 里用 `match key` 映射当前用到的几个 `message.*` key
   - 参数化文本只覆盖当前恢复到的调用点
   - 未命中的 key 回退成原 key 或 fallback message

5. **以测试通过为收口信号**
   - 补完最小兼容层后，立即重新跑：

```bash
cd backend
cargo test
```

   - 如果编译与测试恢复，就说明这次恢复已经闭环
   - 真正的全局 i18n error 协议，应该留给独立 plan / feature 去做

## Why This Matters

这类恢复最容易犯的错误，是把“当前要保住主分支可用”与“顺手完成旧分支里未收口的基础设施升级”混在一起。

如果一看到 `with_message_key` 不存在，就去全局改 `AppError`、`ErrorResponse`、middleware、catalog，短期会带来三层风险：

1. **范围失控**
   - 原本只是恢复 `message.rs`
   - 最后变成 backend 错误协议升级

2. **验证成本陡增**
   - 原本 `cargo test` 就能兜住
   - 变成要同时验证多语言协议、客户端兼容、契约测试

3. **主分支稳定性下降**
   - 恢复类工作本来应该偏保守
   - 一旦顺手推进半套基础设施，容易把旧快照问题引成新的主线问题

所以更稳的策略是：

- 先在文件内补最小兼容层
- 让恢复文件重新落到当前主分支的能力边界内
- 等后续真正做 i18n 收口时，再把这些局部 helper 收束成全局抽象

## When to Apply

- 你在恢复旧 Rust handler / service 文件
- 恢复文件来自更“超前”的分支或脏工作区快照
- 当前主分支没有那套配套的 error/i18n 基础设施
- 任务目标是“恢复有效改动并保持可编译”
- 你已经能用少量 helper 把调用点压回当前抽象层

## Examples

### 这次实际遇到的编译失败信号

恢复 `message.rs` 后，`cargo test` 报错集中在：

- `parse_message_sender_id` not found
- `message_forbidden_error` not found
- `message_validation_error` not found
- `MessageParams` undeclared
- `AppError::with_message_key` method not found

这说明问题不在业务逻辑，而在于恢复文件依赖了尚未同时恢复的 i18n/error 支撑层。

### 这次采用的做法

在 `backend/src/handlers/message.rs` 内补了一组局部 helper：

```rust
type MessageParams = HashMap<String, String>;

fn parse_message_sender_id(claim_sub: &str) -> Result<Uuid, AppError> { ... }
fn message_forbidden_error(key: &str) -> AppError { ... }
fn message_validation_error(key: &str) -> AppError { ... }
fn message_validation_error_with_params(key: &str, params: MessageParams) -> AppError { ... }
fn message_internal_error(key: &str, fallback: String) -> AppError { ... }
fn message_not_found_error(key: &str) -> AppError { ... }
```

然后把原先依赖 `with_message_key(...)` 的调用改成当前主分支可承受的形式，例如：

```rust
return Err(message_not_found_error("message.attachment_not_found"));
```

### 不推荐做法

不建议在这类恢复里直接扩展：

- `backend/src/error.rs`
- 全局 `ErrorResponse` 协议
- backend i18n catalog 加载路径
- 客户端 `message_key` 消费逻辑

这些都应该由独立的 i18n 收口任务来推进，而不是搭在一次 restore 提交上。

### 验证方式

这次补完最小兼容层后，用下面的命令重新确认：

```bash
cd backend
cargo test
```

结果恢复为：

- backend lib tests 全通过
- smoke test 通过
- 主分支可继续做后续文档与脚本恢复

## Related

- `docs/solutions/workflow-issues/ce-hard-cut-dirty-main-recovery-2026-04-04.md`
- 提交：`9d87cafa` `chore(workspace): restore pre-ce merge local changes`
- 文件：`backend/src/handlers/message.rs`
- 计划：`docs/plans/2026-04-01-i18n-tail-closure-plan.md`
