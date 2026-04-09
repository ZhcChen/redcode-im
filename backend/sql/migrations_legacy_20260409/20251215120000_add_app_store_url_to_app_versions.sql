-- 20251215120000_add_app_store_url_to_app_versions.sql
-- 为 app_versions 增加 App Store 链接字段（用于 iOS/macOS 的“商店安装”入口）

ALTER TABLE app_versions
  ADD COLUMN IF NOT EXISTS app_store_url TEXT;

