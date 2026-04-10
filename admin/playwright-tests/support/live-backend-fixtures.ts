import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

export const liveChatFixture = {
  userAId: '11111111-1111-4111-8111-111111111111',
  userBId: '22222222-2222-4222-8222-222222222222',
  roomId: '33333333-3333-4333-8333-333333333333',
  roomName: '联调测试房间',
  messageA: '联调消息 A',
  messageB: '联调消息 B',
};

export const liveRbacFixturePrefix = 'liverbace2e';

let seeded = false;

function execLivePostgresSql(sql: string) {
  const composeFile = resolve(
    __dirname,
    '../../../backend/docker/dev/docker-compose.yml'
  );

  try {
    execFileSync(
      'docker',
      [
        'compose',
        '-f',
        composeFile,
        'exec',
        '-T',
        'postgres',
        'psql',
        '-U',
        'postgres',
        '-d',
        'redcode_im',
        '-v',
        'ON_ERROR_STOP=1',
        '-c',
        sql,
      ],
      {
        stdio: 'pipe',
        encoding: 'utf-8',
      }
    );
  } catch (error) {
    throw new Error(`执行 live postgres SQL 失败: ${String(error)}`);
  }
}

export function ensureLiveChatFixtureSeeded() {
  if (seeded) {
    return;
  }

  const sql = `
INSERT INTO users (
  id, username, email, password_hash, nickname, status, created_at, updated_at, deleted_at
)
VALUES
  (
    '${liveChatFixture.userAId}',
    'live_chat_user_a',
    'live_chat_user_a@redcode-im.local',
    'live-chat-fixture-password-hash',
    '联调用户A',
    0,
    NOW(),
    NOW(),
    NULL
  ),
  (
    '${liveChatFixture.userBId}',
    'live_chat_user_b',
    'live_chat_user_b@redcode-im.local',
    'live-chat-fixture-password-hash',
    '联调用户B',
    0,
    NOW(),
    NOW(),
    NULL
  )
ON CONFLICT (id) DO UPDATE
SET
  username = EXCLUDED.username,
  email = EXCLUDED.email,
  nickname = EXCLUDED.nickname,
  status = EXCLUDED.status,
  deleted_at = NULL,
  updated_at = NOW();

INSERT INTO rooms (
  id, name, description, room_type, owner_id, created_at, updated_at, deleted_at
)
VALUES (
  '${liveChatFixture.roomId}',
  '${liveChatFixture.roomName}',
  'admin live smoke fixture',
  1,
  '${liveChatFixture.userAId}',
  NOW(),
  NOW(),
  NULL
)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  room_type = EXCLUDED.room_type,
  owner_id = EXCLUDED.owner_id,
  deleted_at = NULL,
  updated_at = NOW();

INSERT INTO room_members (
  id, room_id, user_id, role, joined_at, deleted_at, notification_settings
)
VALUES
  (
    '44444444-4444-4444-8444-444444444441',
    '${liveChatFixture.roomId}',
    '${liveChatFixture.userAId}',
    0,
    NOW(),
    NULL,
    0
  ),
  (
    '44444444-4444-4444-8444-444444444442',
    '${liveChatFixture.roomId}',
    '${liveChatFixture.userBId}',
    2,
    NOW(),
    NULL,
    0
  )
ON CONFLICT (room_id, user_id) WHERE deleted_at IS NULL DO UPDATE
SET
  role = EXCLUDED.role,
  joined_at = EXCLUDED.joined_at,
  notification_settings = EXCLUDED.notification_settings,
  deleted_at = NULL;

INSERT INTO messages (
  id, room_id, sender_id, content, message_type, created_at, updated_at, deleted_at
)
VALUES
  (
    '55555555-5555-4555-8555-555555555551',
    '${liveChatFixture.roomId}',
    '${liveChatFixture.userAId}',
    '${liveChatFixture.messageA}',
    0,
    NOW() - INTERVAL '2 minutes',
    NOW() - INTERVAL '2 minutes',
    NULL
  ),
  (
    '55555555-5555-4555-8555-555555555552',
    '${liveChatFixture.roomId}',
    '${liveChatFixture.userBId}',
    '${liveChatFixture.messageB}',
    0,
    NOW() - INTERVAL '1 minute',
    NOW() - INTERVAL '1 minute',
    NULL
  )
ON CONFLICT (id) DO UPDATE
SET
  room_id = EXCLUDED.room_id,
  sender_id = EXCLUDED.sender_id,
  content = EXCLUDED.content,
  message_type = EXCLUDED.message_type,
  created_at = EXCLUDED.created_at,
  updated_at = EXCLUDED.updated_at,
  deleted_at = NULL;

UPDATE rooms
SET updated_at = NOW()
WHERE id = '${liveChatFixture.roomId}';
`;

  execLivePostgresSql(sql);
  seeded = true;
}

export function cleanupLiveRbacFixtures() {
  const sql = `
DELETE FROM admin_operation_logs
WHERE resource_type = 'admin_user'
  AND resource_id IN (
    SELECT id
    FROM admin_users
    WHERE username LIKE '${liveRbacFixturePrefix}%'
       OR email LIKE '${liveRbacFixturePrefix}%'
  );

DELETE FROM admin_user_roles
WHERE admin_user_id IN (
    SELECT id
    FROM admin_users
    WHERE username LIKE '${liveRbacFixturePrefix}%'
       OR email LIKE '${liveRbacFixturePrefix}%'
  )
   OR role_id IN (
    SELECT id
    FROM roles
    WHERE code LIKE '${liveRbacFixturePrefix}%'
  );

DELETE FROM admin_users
WHERE username LIKE '${liveRbacFixturePrefix}%'
   OR email LIKE '${liveRbacFixturePrefix}%';

DELETE FROM roles
WHERE code LIKE '${liveRbacFixturePrefix}%';
`;

  execLivePostgresSql(sql);
}
