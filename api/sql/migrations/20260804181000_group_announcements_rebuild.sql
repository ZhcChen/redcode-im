-- 修正 2.0 能力迁移中的群公告表结构。
-- base.sql 已存在旧版 group_announcements（id/title/publisher_id/is_pinned，
-- 无业务引用且无数据），20260804180000 的 IF NOT EXISTS 不会重建该表，
-- 因此这里显式重建为“每群单条公告”结构。

DROP TABLE IF EXISTS public.group_announcements;

CREATE TABLE public.group_announcements (
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    content text NOT NULL,
    created_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    updated_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp with time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_id)
);

COMMENT ON TABLE public.group_announcements IS '群公告：每群至多一条当前公告，覆盖式更新';
