-- 补齐群聊详情视图：group_detail_view
--
-- 说明：
-- - 后端 `GroupManagementStore::get_group_detail_info` 依赖该视图；
-- - base.sql 的历史版本曾包含该视图，但现版本缺失，导致 /rooms/:room_id/detail 返回 500。

CREATE OR REPLACE VIEW group_detail_view AS
SELECT
    r.id,
    r.name,
    r.description,
    r.avatar_url,
    r.avatar_object_key,
    r.room_type,
    r.owner_id,
    r.created_at,
    r.updated_at,
    COALESCE(gs.join_approval_required, FALSE) AS join_approval_required,
    COALESCE(gs.member_can_invite, TRUE) AS member_can_invite,
    COALESCE(gs.member_can_add_friends, TRUE) AS member_can_add_friends,
    COALESCE(gs.require_admin_to_add_friends, FALSE) AS require_admin_to_add_friends,
    COALESCE(gs.max_members, 500) AS max_members,
    COALESCE(gs.global_mute_enabled, FALSE) AS global_mute_enabled,
    gs.global_mute_until,
    gs.global_mute_reason,
    gs.global_mute_set_by,
    (
        SELECT COUNT(*)
        FROM room_members rm
        WHERE rm.room_id = r.id AND rm.deleted_at IS NULL
    ) AS current_member_count,
    (
        SELECT COUNT(*)
        FROM join_requests jr
        WHERE jr.room_id = r.id AND jr.status = 0
    ) AS pending_request_count
FROM rooms r
LEFT JOIN group_settings gs ON r.id = gs.room_id
WHERE r.room_type = 1 AND r.deleted_at IS NULL;

