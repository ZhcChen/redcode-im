CREATE OR REPLACE FUNCTION bump_e2ee_room_membership_revision()
RETURNS TRIGGER AS $$
DECLARE
    affected_room_id UUID;
    active_membership_changed BOOLEAN;
BEGIN
    IF TG_OP = 'INSERT' THEN
        affected_room_id := NEW.room_id;
        active_membership_changed := NEW.deleted_at IS NULL;
    ELSIF TG_OP = 'DELETE' THEN
        affected_room_id := OLD.room_id;
        active_membership_changed := OLD.deleted_at IS NULL;
    ELSE
        affected_room_id := NEW.room_id;
        active_membership_changed :=
            (OLD.deleted_at IS NULL) IS DISTINCT FROM (NEW.deleted_at IS NULL);
    END IF;

    IF active_membership_changed
       AND EXISTS (SELECT 1 FROM rooms WHERE id = affected_room_id) THEN
        INSERT INTO e2ee_room_epochs (room_id, membership_revision, active_epoch, status)
        VALUES (affected_room_id, 1, 0, 'preparing')
        ON CONFLICT (room_id) DO UPDATE
        SET membership_revision = e2ee_room_epochs.membership_revision + 1,
            status = CASE
                WHEN e2ee_room_epochs.status = 'active' THEN 'rekey_required'
                ELSE e2ee_room_epochs.status
            END,
            updated_at = NOW();
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION bump_e2ee_room_membership_revision() IS
    '活跃房间成员集合变化时推进 E2EE revision；房间级联删除期间不重建 epoch';
