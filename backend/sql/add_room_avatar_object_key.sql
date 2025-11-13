-- 添加 avatar_object_key 字段到 rooms 表
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS avatar_object_key TEXT;
