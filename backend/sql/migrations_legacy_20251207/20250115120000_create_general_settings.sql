-- 通用设置表
-- 用于存储应用的通用配置，如应用名称等
CREATE TABLE IF NOT EXISTS general_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- 插入默认应用名称
INSERT INTO general_settings (key, value, description, updated_at)
VALUES ('app_name', 'Redcode IM', '应用名称', NOW())
ON CONFLICT (key) DO NOTHING;

