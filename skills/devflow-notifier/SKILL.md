---
name: devflow-notifier
description: Telegram 通知类 skill，在本轮任务全部完成时发送消息，并支持本地绑定配置。
---

# 目标

- 在任务全部完成时发送通知
- 会话开始即检查绑定状态并提示用户绑定
- 提供脚本化调用能力，便于 Orchestrator 触发

# 使用方式

1. 会话开始先检查绑定：若 `.env` 不存在，提示用户执行绑定并停止后续动作
2. 运行 `scripts/setup_tg_env.sh` 生成本地 `.env`，或手动创建
3. 使用 `scripts/notify_tg.sh` 发送通知

# 绑定配置

- `.env` 路径：`skills/devflow-notifier/.env`
- 必需变量：`TG_BOT_TOKEN`、`TG_CHAT_ID`
- `.env` 仅本地存放，需保持 git 忽略

# 通知触发时机

- 仅在“本轮任务全部完成”时触发

# 参考

- PRD：[docs/requirements/PRD-000001.md](../../docs/requirements/PRD-000001.md)
- SPEC：[docs/specs/SPEC-000001.md](../../docs/specs/SPEC-000001.md)
