-- 为表情包表添加类型和父级关系字段
-- 支持单个表情包和表情包套件（系列）

-- 添加 type 字段：0=单个表情包, 1=表情包套件
ALTER TABLE emoji_packs
ADD COLUMN IF NOT EXISTS pack_type SMALLINT NOT NULL DEFAULT 0;

-- 添加 parent_id 字段：指向父套件ID，单个表情包或套件父节点的 parent_id 为 NULL
ALTER TABLE emoji_packs
ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES emoji_packs(id) ON DELETE CASCADE;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_emoji_packs_pack_type ON emoji_packs(pack_type);
CREATE INDEX IF NOT EXISTS idx_emoji_packs_parent_id ON emoji_packs(parent_id);

-- 更新现有记录：确保所有现有表情包都是单个类型，parent_id 为 NULL
UPDATE emoji_packs
SET pack_type = 0, parent_id = NULL
WHERE pack_type IS NULL OR parent_id IS NOT NULL;

