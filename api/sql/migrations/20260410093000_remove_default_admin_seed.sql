-- 移除 base.sql 中的默认管理员 seed，改为运行时 bootstrap 初始化首个超级管理员。
DO $$
DECLARE
    seed_admin_id UUID;
BEGIN
    SELECT id
      INTO seed_admin_id
      FROM admin_users
     WHERE username = 'admin'
       AND email = 'admin@redcode-im.com'
       AND deleted_at IS NULL
     LIMIT 1;

    IF seed_admin_id IS NOT NULL THEN
        DELETE FROM admin_user_roles
         WHERE admin_user_id = seed_admin_id
            OR assigned_by = seed_admin_id;

        DELETE FROM admin_login_history
         WHERE admin_user_id = seed_admin_id;

        DELETE FROM admin_users
         WHERE id = seed_admin_id;
    END IF;
END $$;
