-- 用户登录历史表（用于审计和安全分析）
CREATE TABLE IF NOT EXISTS user_login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    login_method VARCHAR(50) NOT NULL DEFAULT 'websocket', -- websocket, api, etc.
    login_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logout_at TIMESTAMPTZ,
    session_duration INTERVAL GENERATED ALWAYS AS (logout_at - login_at) STORED,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    failure_reason TEXT,
    device_info JSONB, -- 存储设备信息，如操作系统、浏览器等
    location_info JSONB -- 存储地理位置信息（可选，通过IP解析获得）
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_login_history_user_id ON user_login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_login_history_login_at ON user_login_history(login_at);
CREATE INDEX IF NOT EXISTS idx_user_login_history_ip_address ON user_login_history(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_login_history_success ON user_login_history(success);
CREATE INDEX IF NOT EXISTS idx_user_login_history_logout_at ON user_login_history(logout_at) WHERE logout_at IS NOT NULL;

-- 复合索引：用户+登录时间（用于查询用户登录历史）
CREATE INDEX IF NOT EXISTS idx_user_login_history_user_login_at
    ON user_login_history(user_id, login_at DESC);

-- 复合索引：IP+登录时间（用于安全分析，检测异常登录）
CREATE INDEX IF NOT EXISTS idx_user_login_history_ip_login_at
    ON user_login_history(ip_address, login_at DESC);

-- 用户心跳记录表（记录用户在线状态和IP变化）
CREATE TABLE IF NOT EXISTS user_heartbeat_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    connection_id TEXT NOT NULL, -- WebSocket连接ID
    heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    node_id VARCHAR(100), -- 节点ID（用于分布式部署）
    device_info JSONB
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_user_id ON user_heartbeat_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_heartbeat_at ON user_heartbeat_logs(heartbeat_at);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_ip_address ON user_heartbeat_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_connection_id ON user_heartbeat_logs(connection_id);

-- 复合索引：用户+心跳时间（用于查询用户在线时段）
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_user_heartbeat_at
    ON user_heartbeat_logs(user_id, heartbeat_at DESC);

-- 分区表（按月分区，提高查询性能）
-- 注意：PostgreSQL分区需要先创建主表，然后创建分区
-- 这里暂时不创建分区，在生产环境中可以根据需要添加

-- 清理过期数据的函数（保留最近1年的数据）
CREATE OR REPLACE FUNCTION cleanup_old_user_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- 删除1年前的用户登录历史
    DELETE FROM user_login_history
    WHERE login_at < NOW() - INTERVAL '1 year';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- 删除3个月前的用户心跳记录
    DELETE FROM user_heartbeat_logs
    WHERE heartbeat_at < NOW() - INTERVAL '3 months';

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 创建定期清理任务的注释说明
COMMENT ON FUNCTION cleanup_old_user_logs() IS '清理过期用户日志数据，保留最近1年的登录历史和3个月的心跳记录。建议设置为定时任务每月执行一次。';

COMMENT ON TABLE user_login_history IS '用户登录历史记录，用于审计和安全分析';
COMMENT ON TABLE user_heartbeat_logs IS '用户心跳记录，用于跟踪用户在线状态和IP变化';
