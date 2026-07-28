-- 用户级房间偏好：群目录收藏与会话归档。
-- 不承载房间成员关系、群全局设置或消息历史。

CREATE TABLE IF NOT EXISTS public.user_room_preferences (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    group_directory_favorited_at timestamp with time zone,
    chat_archived_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp with time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, room_id)
);

COMMENT ON TABLE public.user_room_preferences IS '用户级房间偏好：群目录收藏与会话归档';
COMMENT ON COLUMN public.user_room_preferences.group_directory_favorited_at IS '收藏群聊到联系人群目录的时间；NULL 表示未收藏';
COMMENT ON COLUMN public.user_room_preferences.chat_archived_at IS '从当前用户聊天收件箱归档的时间；NULL 表示未归档';

CREATE INDEX IF NOT EXISTS idx_user_room_preferences_group_directory_favorite
    ON public.user_room_preferences (user_id, group_directory_favorited_at DESC)
    WHERE group_directory_favorited_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_room_preferences_chat_archive
    ON public.user_room_preferences (user_id, chat_archived_at DESC)
    WHERE chat_archived_at IS NOT NULL;
