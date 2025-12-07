-- 创建表情包功能相关表
-- 包含：表情包表、表情项表、用户表情包关联表

-- 表情包表
CREATE TABLE IF NOT EXISTS emoji_packs (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon_url TEXT,
    description TEXT,
    is_active SMALLINT NOT NULL DEFAULT 1,  -- 0=inactive, 1=active
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 表情项表
CREATE TABLE IF NOT EXISTS emoji_items (
    id UUID PRIMARY KEY,
    pack_id UUID NOT NULL REFERENCES emoji_packs(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    name VARCHAR(100),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 用户表情包关联表
CREATE TABLE IF NOT EXISTS user_emoji_packs (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pack_id UUID NOT NULL REFERENCES emoji_packs(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, pack_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_emoji_packs_is_active ON emoji_packs(is_active);
CREATE INDEX IF NOT EXISTS idx_emoji_items_pack_id ON emoji_items(pack_id);
CREATE INDEX IF NOT EXISTS idx_emoji_items_sort_order ON emoji_items(pack_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_user_emoji_packs_user_id ON user_emoji_packs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_emoji_packs_pack_id ON user_emoji_packs(pack_id);

