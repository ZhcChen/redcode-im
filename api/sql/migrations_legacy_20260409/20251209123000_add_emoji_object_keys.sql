-- 20251209123000_add_emoji_object_keys.sql
-- 为表情包与表情项增加 COS 对象键字段，用于生成临时下载地址

-- 为 emoji_packs 表增加 icon_object_key 字段（COS 对象键）
ALTER TABLE emoji_packs
    ADD COLUMN IF NOT EXISTS icon_object_key TEXT;

-- 为 emoji_items 表增加 image_object_key 字段（COS 对象键）
ALTER TABLE emoji_items
    ADD COLUMN IF NOT EXISTS image_object_key TEXT;

