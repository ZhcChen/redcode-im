-- 恢复 emoji_packs 表的 pack_type 与 parent_id 字段（之前在合并 all.sql 时遗漏）
-- 0=单个表情包，1=表情包套件

ALTER TABLE emoji_packs
ADD COLUMN IF NOT EXISTS pack_type SMALLINT NOT NULL DEFAULT 0;

ALTER TABLE emoji_packs
ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES emoji_packs(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_emoji_packs_pack_type ON emoji_packs(pack_type);
CREATE INDEX IF NOT EXISTS idx_emoji_packs_parent_id ON emoji_packs(parent_id);

-- 兼容已有数据，确保默认值正确
UPDATE emoji_packs
SET pack_type = 0, parent_id = NULL
WHERE pack_type IS NULL OR parent_id IS NOT NULL;
