# API 测试覆盖补齐说明（2026-01-19）

## 结论
- 管理后台当前**不实现**角色管理与文件管理相关功能，仅保留接口占位。
- 相关接口仅用于占位或演示，测试不应依赖“404/不存在”语义。
- COS 与 Geolocation 配置尚未完成，相关测试需要等待配置后再验证。

## 接口现状（占位/简化）
- `/api/admin/roles/*`：简化实现，不读 DB；非系统角色直接返回成功。
- `/api/admin/files/*`：简化实现；删除接口要求 JSON body，否则返回 400。
- `/admin/data/cleanup/all`：开发环境清理数据的高危接口，当前实现无确认参数。

## 待办（配置完成后处理）
- 从现有数据库导出 seed SQL：
  - `storage_providers`（COS 配置）
  - `ipinfo_tokens`（地理位置 token）
  - 可选：`general_settings` 中 `ip_geolocation_enabled`
- 生成独立的初始化脚本用于新测试库（不清空现有数据库）。

## 备注
- 测试数据库不要清空，避免反复配置 COS 与 geolocation。 
- 配置完成后通知我，再生成 seeds SQL 脚本。
