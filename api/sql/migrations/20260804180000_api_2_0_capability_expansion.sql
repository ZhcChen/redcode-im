-- API 2.0 能力补齐：个性签名 / 黑名单 / 群公告 / 消息收藏 / 登录设备 / 扫码登录。
-- 全部 additive，不修改既有表语义。

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS signature text;

CREATE TABLE IF NOT EXISTS public.user_blocks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blocker_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id),
    CONSTRAINT user_blocks_unique UNIQUE (blocker_id, blocked_id)
);

COMMENT ON TABLE public.user_blocks IS '用户黑名单：拉黑者到被拉黑用户的一对多关系';

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker
    ON public.user_blocks (blocker_id);

CREATE TABLE IF NOT EXISTS public.group_announcements (
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    content text NOT NULL,
    created_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    updated_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp with time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_id)
);

COMMENT ON TABLE public.group_announcements IS '群公告：每群至多一条当前公告，覆盖式更新';

CREATE TABLE IF NOT EXISTS public.message_favorites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    message_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id),
    CONSTRAINT message_favorites_unique UNIQUE (user_id, message_id)
);

COMMENT ON TABLE public.message_favorites IS '消息收藏：仅收藏者本人可见';

CREATE INDEX IF NOT EXISTS idx_message_favorites_user
    ON public.message_favorites (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.user_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_name text NOT NULL DEFAULT 'unknown',
    platform text NOT NULL DEFAULT 'unknown',
    last_seen_at timestamp with time zone NOT NULL DEFAULT NOW(),
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    revoked_at timestamp with time zone,
    PRIMARY KEY (id)
);

COMMENT ON TABLE public.user_devices IS '登录设备登记：用于设备列表与撤销下线';

CREATE INDEX IF NOT EXISTS idx_user_devices_user
    ON public.user_devices (user_id);

CREATE TABLE IF NOT EXISTS public.qr_login_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    qr_token uuid NOT NULL,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'cancelled', 'expired')),
    login_code text,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    confirmed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    PRIMARY KEY (id)
);

COMMENT ON TABLE public.qr_login_sessions IS 'PC 扫码登录会话：一次性使用，PC 端轮询/WS 实时接收结果';

CREATE INDEX IF NOT EXISTS idx_qr_login_sessions_token
    ON public.qr_login_sessions (qr_token);

CREATE INDEX IF NOT EXISTS idx_qr_login_sessions_status
    ON public.qr_login_sessions (status, expires_at);
