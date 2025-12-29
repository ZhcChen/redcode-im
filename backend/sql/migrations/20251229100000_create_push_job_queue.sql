-- 20251229100000_create_push_job_queue.sql
-- 创建 Push Job 队列表（用于 push job 的落库与重试）
--
-- 设计目标：
-- 1) 当内存 push job 队列满时，push job 不丢弃，落库等待重试
-- 2) 支持多节点消费：FOR UPDATE SKIP LOCKED 认领任务，next_run_at 作为租约
-- 3) 不使用 PostgreSQL ENUM，status 使用 SMALLINT

CREATE TABLE IF NOT EXISTS push_job_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 任务类型（message/friend_request/group_event 等）
    job_type TEXT NOT NULL,

    -- 任务 payload（JSON，按 job_type 解释）
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- 任务状态：0=pending, 1=done, 2=failed, 3=retry
    status SMALLINT NOT NULL DEFAULT 0,

    -- 已尝试次数（用于退避与失败判定）
    attempts INTEGER NOT NULL DEFAULT 0,

    -- 下次可执行时间（<= NOW() 表示可被认领；同时作为租约避免多节点重复处理）
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 最后一次错误信息（用于排障）
    last_error TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_push_job_queue_due
    ON push_job_queue(status, next_run_at, created_at);

COMMENT ON TABLE push_job_queue IS 'Push job 队列：用于 push job 落库与重试（内存队列溢出时使用）';
COMMENT ON COLUMN push_job_queue.job_type IS '任务类型：message/friend_request/group_event';
COMMENT ON COLUMN push_job_queue.payload IS '任务 payload（JSON）';
COMMENT ON COLUMN push_job_queue.status IS '任务状态：0=pending,1=done,2=failed,3=retry';
COMMENT ON COLUMN push_job_queue.attempts IS '已尝试次数（用于退避与失败判定）';
COMMENT ON COLUMN push_job_queue.next_run_at IS '下次可执行时间；也用作多节点租约';
COMMENT ON COLUMN push_job_queue.last_error IS '最后一次错误信息';
