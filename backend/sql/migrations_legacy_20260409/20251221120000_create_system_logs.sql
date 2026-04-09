-- 系统日志表
-- 用于存储应用运行日志，支持 7 天自动清理

CREATE TABLE IF NOT EXISTS system_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    level VARCHAR(10) NOT NULL,              -- TRACE/DEBUG/INFO/WARN/ERROR
    target VARCHAR(255) NOT NULL,            -- 模块路径 (e.g., redcode_im_backend::handlers::auth)
    message TEXT NOT NULL,                   -- 日志消息
    fields JSONB,                            -- 结构化字段
    span_id VARCHAR(64),                     -- tracing span ID
    node_id VARCHAR(100),                    -- 节点标识
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引优化查询
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_target ON system_logs(target);
CREATE INDEX IF NOT EXISTS idx_system_logs_level_created ON system_logs(level, created_at DESC);

-- 添加注释
COMMENT ON TABLE system_logs IS '系统日志表，存储 DEBUG/WARN/ERROR 级别日志，7天自动清理';
COMMENT ON COLUMN system_logs.level IS '日志级别: TRACE/DEBUG/INFO/WARN/ERROR';
COMMENT ON COLUMN system_logs.target IS '日志来源模块路径';
COMMENT ON COLUMN system_logs.message IS '日志消息内容';
COMMENT ON COLUMN system_logs.fields IS '结构化字段 (JSON)';
COMMENT ON COLUMN system_logs.span_id IS 'Tracing Span ID';
COMMENT ON COLUMN system_logs.node_id IS '产生日志的节点标识';
