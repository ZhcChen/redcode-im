-- 20251227024227_create_message_reactions.sql
-- 创建消息反应表（Message Reactions）
--
-- 设计目标：
-- 1) 支持用户对消息添加表情反应（👍 ❤️ 😂 🎉 😮 😢 等）
-- 2) 每个用户对同一条消息、同一种 reaction 只能有 0/1（点击即 toggle）
-- 3) 反应类型固定集合，避免自定义导致兼容成本
-- 4) 支持软删除（deleted_at），便于恢复和审计

CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联消息
    message_id UUID NOT NULL
        REFERENCES messages(id) ON DELETE CASCADE,
    
    -- 关联用户（添加反应的用户）
    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    
    -- 反应类型（固定集合：👍 ❤️ 😂 🎉 😮 😢）
    -- 使用 TEXT 而非枚举，符合项目规范
    reaction_key TEXT NOT NULL,
    
    -- 创建时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 删除时间（软删除，支持恢复）
    deleted_at TIMESTAMPTZ,
    
    -- 唯一约束：同一用户对同一条消息的同一种反应只能有一条记录
    CONSTRAINT message_reactions_unique_user_message_reaction
        UNIQUE (message_id, user_id, reaction_key)
);

-- 索引：按消息查询所有反应（用于聚合显示）
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id
    ON message_reactions(message_id)
    WHERE deleted_at IS NULL;

-- 索引：按用户查询反应（可选，用于用户个人反应历史）
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id
    ON message_reactions(user_id)
    WHERE deleted_at IS NULL;

-- 索引：按消息和反应类型聚合（用于快速统计每种反应的数量）
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_reaction
    ON message_reactions(message_id, reaction_key)
    WHERE deleted_at IS NULL;

COMMENT ON TABLE message_reactions IS '消息反应表，记录用户对消息的表情反应';
COMMENT ON COLUMN message_reactions.reaction_key IS '反应类型：👍 ❤️ 😂 🎉 😮 😢 等固定表情';
COMMENT ON COLUMN message_reactions.deleted_at IS '软删除时间，NULL 表示未删除';

