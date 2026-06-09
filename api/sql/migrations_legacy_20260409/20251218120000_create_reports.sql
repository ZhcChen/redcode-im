-- 20251218120000_create_reports.sql
-- 创建举报（群聊/用户）与附件记录表
--
-- 说明：
-- - target_type: 1=room（群聊/房间），2=user（用户）
-- - 举报必须包含内容与至少 1 张截图附件（由业务层保证）

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 1=room, 2=user
    target_type INTEGER NOT NULL,
    target_room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,

    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (target_type IN (1, 2)),
    CHECK (
        (target_type = 1 AND target_room_id IS NOT NULL AND target_user_id IS NULL)
        OR
        (target_type = 2 AND target_user_id IS NOT NULL AND target_room_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_target_type ON reports(target_type);
CREATE INDEX IF NOT EXISTS idx_reports_target_room_id ON reports(target_room_id);
CREATE INDEX IF NOT EXISTS idx_reports_target_user_id ON reports(target_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

CREATE TABLE IF NOT EXISTS report_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL,
    content_type TEXT,
    file_size BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(report_id, object_key)
);

CREATE INDEX IF NOT EXISTS idx_report_attachments_report_id ON report_attachments(report_id);
CREATE INDEX IF NOT EXISTS idx_report_attachments_object_key ON report_attachments(object_key);
