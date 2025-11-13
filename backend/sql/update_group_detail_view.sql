-- Update group_detail_view to include avatar_object_key
DROP VIEW IF EXISTS group_detail_view;

CREATE VIEW group_detail_view AS
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
    gs.join_approval_required,
    gs.member_can_invite,
    gs.member_can_add_friends,
    gs.require_admin_to_add_friends,
    gs.max_members,
    (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.id AND rm.deleted_at IS NULL) AS current_member_count,
    (SELECT COUNT(*) FROM group_announcements ga WHERE ga.room_id = r.id) AS announcement_count,
    (SELECT COUNT(*) FROM join_requests jr WHERE jr.room_id = r.id AND jr.status = 0) AS pending_request_count
FROM rooms r
LEFT JOIN group_settings gs ON r.id = gs.room_id
WHERE r.room_type = 1 AND r.deleted_at IS NULL;
