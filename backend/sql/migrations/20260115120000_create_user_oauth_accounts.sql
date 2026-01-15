-- 为第三方登录（OAuth/OIDC）提供账号绑定表
-- 注意：不使用 PostgreSQL enum，避免迁移与类型演进成本

CREATE TABLE IF NOT EXISTS user_oauth_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider, provider_user_id),
    UNIQUE(user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_user_oauth_accounts_user_id
    ON user_oauth_accounts (user_id);

