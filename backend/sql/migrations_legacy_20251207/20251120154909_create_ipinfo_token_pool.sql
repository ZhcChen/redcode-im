-- ipinfo.io API Token 池管理表
CREATE TABLE IF NOT EXISTS ipinfo_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE, -- Token 名称/标识
    token VARCHAR(200) NOT NULL UNIQUE, -- API Token
    monthly_limit INTEGER NOT NULL DEFAULT 50000, -- 月额度限制
    used_count INTEGER NOT NULL DEFAULT 0, -- 已使用次数
    reset_date DATE NOT NULL DEFAULT CURRENT_DATE, -- 重置日期（每月1号）
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted')),
    last_used_at TIMESTAMPTZ, -- 最后使用时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_status ON ipinfo_tokens(status);
CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_reset_date ON ipinfo_tokens(reset_date);
CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_last_used_at ON ipinfo_tokens(last_used_at);

-- 用户地理位置表（每个用户一条最新记录）
CREATE TABLE IF NOT EXISTS user_geolocations (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    isp VARCHAR(200),
    timezone VARCHAR(50),
    zip_code VARCHAR(20),
    geolocation_source VARCHAR(50) DEFAULT 'ipinfo', -- 数据来源
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_geolocations_ip ON user_geolocations(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_country ON user_geolocations(country);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_updated_at ON user_geolocations(updated_at);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_city ON user_geolocations(city);

-- Token 使用记录表（可选，用于详细审计）
CREATE TABLE IF NOT EXISTS ipinfo_token_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id UUID NOT NULL REFERENCES ipinfo_tokens(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    request_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    response_status INTEGER, -- HTTP响应状态码
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_ipinfo_token_usage_logs_token_id ON ipinfo_token_usage_logs(token_id);
CREATE INDEX IF NOT EXISTS idx_ipinfo_token_usage_logs_request_at ON ipinfo_token_usage_logs(request_at);
CREATE INDEX IF NOT EXISTS idx_ipinfo_token_usage_logs_user_id ON ipinfo_token_usage_logs(user_id);

-- 更新时间触发器
CREATE TRIGGER update_ipinfo_tokens_updated_at
    BEFORE UPDATE ON ipinfo_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_geolocations_updated_at
    BEFORE UPDATE ON user_geolocations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 月度重置Token使用量的函数
CREATE OR REPLACE FUNCTION reset_ipinfo_token_usage()
RETURNS INTEGER AS $$
DECLARE
    current_month DATE := DATE_TRUNC('month', CURRENT_DATE);
    reset_count INTEGER;
BEGIN
    -- 重置本月的Token使用量
    UPDATE ipinfo_tokens
    SET used_count = 0,
        status = 'active',
        reset_date = current_month + INTERVAL '1 month',
        updated_at = NOW()
    WHERE reset_date <= CURRENT_DATE;

    GET DIAGNOSTICS reset_count = ROW_COUNT;

    -- 记录重置日志（可选）
    IF reset_count > 0 THEN
        RAISE NOTICE '重置了 % 个ipinfo.io Token的使用量', reset_count;
    END IF;

    RETURN reset_count;
END;
$$ LANGUAGE plpgsql;

-- 定期清理旧的Token使用日志（保留最近30天）
CREATE OR REPLACE FUNCTION cleanup_old_ipinfo_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM ipinfo_token_usage_logs
    WHERE request_at < NOW() - INTERVAL '30 days';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE ipinfo_tokens IS 'ipinfo.io API Token池管理';
COMMENT ON TABLE user_geolocations IS '用户地理位置信息（每个用户一条最新记录）';
COMMENT ON TABLE ipinfo_token_usage_logs IS 'Token使用详细日志（可选，用于审计）';
COMMENT ON FUNCTION reset_ipinfo_token_usage() IS '重置已到期的Token月度使用量，建议设置为定时任务每月执行';
COMMENT ON FUNCTION cleanup_old_ipinfo_logs() IS '清理30天前的Token使用日志，建议设置为定时任务每月执行';

-- 基础数据：插入一个示例Token（生产环境需要替换为真实Token）
INSERT INTO ipinfo_tokens (name, token, monthly_limit)
VALUES ('default_token', 'your_ipinfo_token_here', 50000)
ON CONFLICT (name) DO NOTHING;
