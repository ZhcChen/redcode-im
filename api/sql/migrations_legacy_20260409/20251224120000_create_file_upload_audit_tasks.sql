-- 20251224120000_create_file_upload_audit_tasks.sql
-- 创建文件内容审核任务表（腾讯云 COS + 数据万象 CI）
--
-- 设计目标：
-- 1) 在不改变“签名 -> 客户端直传 COS -> commit/引用”的上传架构前提下，为所有上传对象建立审核任务记录；
-- 2) 审核调用失败（网络/服务异常等）可入队重试，并在管理后台可视化查看；
-- 3) 审核判定违规后由后端删除 COS 对象，并记录违规原因（供运维追踪/客户端提示）。
--
-- 注意：
-- - 禁用 PostgreSQL enum：scene / media_kind 使用 TEXT；状态使用 SMALLINT；
-- - 本表既充当“队列表”也充当“审核记录表”（同一 provider+object_key 仅一条记录）。

CREATE TABLE IF NOT EXISTS file_upload_audit_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 关联存储提供商（当前主要是腾讯云 COS）
    storage_provider_id UUID NOT NULL
        REFERENCES storage_providers(id) ON DELETE RESTRICT,

    -- 对象在 COS 中的存储路径（object key）
    object_key TEXT NOT NULL,

    -- 业务场景：avatar/room_avatar/message_attachment/report_attachment/version/emoji/...（字符串，便于扩展与后台筛选）
    scene TEXT NOT NULL,

    -- 媒体类型：image/video/audio/text/document/unknown（字符串，便于扩展）
    media_kind TEXT NOT NULL,

    -- 可选：便于审计与排障
    content_type TEXT,
    file_size BIGINT,

    -- 审核任务状态（小整型，避免 enum）
    -- 0=pending（待提交或待查询结果）
    -- 1=approved（审核通过）
    -- 2=rejected（审核拒绝且对象已删除）
    -- 3=retry（失败待重试；也用于“已判定违规但删除失败”的重试）
    -- 4=failed（永久失败/不支持/超过重试次数）
    status SMALLINT NOT NULL DEFAULT 0,

    -- 供应商任务 ID（CI JobId；同步接口为空）
    vendor_job_id TEXT,

    -- 审核结果详情（JSON，存储原始关键字段与归一化结果）
    result JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- 违规原因（可直接展示给客户端/运维）
    rejected_reason TEXT,

    -- 重试信息
    attempts INTEGER NOT NULL DEFAULT 0,
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_error TEXT,

    -- 审核完成时间（通过/拒绝时写入）
    audited_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 同一存储提供商下，一个 object_key 只对应一条审核任务/记录
CREATE UNIQUE INDEX IF NOT EXISTS idx_file_upload_audit_tasks_provider_key
    ON file_upload_audit_tasks(storage_provider_id, object_key);

-- 按状态 + 下次执行时间扫描队列
CREATE INDEX IF NOT EXISTS idx_file_upload_audit_tasks_status_next
    ON file_upload_audit_tasks(status, next_run_at);

-- 便于后台按时间倒序查看
CREATE INDEX IF NOT EXISTS idx_file_upload_audit_tasks_created_at
    ON file_upload_audit_tasks(created_at DESC);

