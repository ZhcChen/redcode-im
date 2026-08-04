use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgConnection, PgPool};
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Clone, FromRow)]
pub struct RoomEpochRecord {
    pub room_id: Uuid,
    pub membership_revision: i64,
    pub active_epoch: i64,
    pub status: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct SubmitControlMessageInput {
    pub id: Uuid,
    pub epoch: i64,
    pub membership_revision: i64,
    pub sender_device_id: Uuid,
    pub recipient_device_id: Option<Uuid>,
    pub content_type: String,
    pub envelope: Vec<u8>,
    pub idempotency_key: Uuid,
}

#[derive(Debug, Clone, FromRow)]
pub struct ControlMessageRecord {
    pub id: Uuid,
    pub room_id: Uuid,
    pub epoch: i64,
    pub membership_revision: i64,
    pub sender_device_id: Uuid,
    pub recipient_device_id: Option<Uuid>,
    pub content_type: String,
    pub envelope: Vec<u8>,
    pub idempotency_key: Uuid,
    pub sequence_no: i64,
    pub created_at: DateTime<Utc>,
}

pub struct E2eeControlStore<'a> {
    pool: &'a PgPool,
}

impl<'a> E2eeControlStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn get_room_epoch(
        &self,
        room_id: Uuid,
        user_id: Uuid,
    ) -> Result<RoomEpochRecord, AppError> {
        sqlx::query_as::<_, RoomEpochRecord>(
            "SELECT epoch.room_id, epoch.membership_revision, epoch.active_epoch,
                    epoch.status, epoch.updated_at
             FROM e2ee_room_epochs AS epoch
             JOIN room_members AS member ON member.room_id = epoch.room_id
             WHERE epoch.room_id = $1 AND member.user_id = $2
               AND member.deleted_at IS NULL",
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("房间 E2EE 状态不存在或无权访问".to_string()))
    }

    pub async fn submit_control_message(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        input: SubmitControlMessageInput,
    ) -> Result<ControlMessageRecord, AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;

        let sender_allowed = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS (
                SELECT 1 FROM e2ee_devices AS device
                JOIN room_members AS member ON member.user_id = device.user_id
                WHERE device.id = $1 AND device.user_id = $2 AND device.status = 'active'
                  AND member.room_id = $3 AND member.deleted_at IS NULL
             )",
        )
        .bind(input.sender_device_id)
        .bind(user_id)
        .bind(room_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;
        if !sender_allowed {
            return Err(AppError::Forbidden(
                "发送设备不是当前房间的可信设备".to_string(),
            ));
        }

        if let Some(recipient_device_id) = input.recipient_device_id {
            let recipient_allowed = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS (
                    SELECT 1 FROM e2ee_devices AS device
                    JOIN room_members AS member ON member.user_id = device.user_id
                    WHERE device.id = $1 AND device.status = 'active'
                      AND member.room_id = $2 AND member.deleted_at IS NULL
                 )",
            )
            .bind(recipient_device_id)
            .bind(room_id)
            .fetch_one(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
            if !recipient_allowed {
                return Err(AppError::Forbidden(
                    "接收设备不是当前房间的可信设备".to_string(),
                ));
            }
        }

        let state = sqlx::query_as::<_, RoomEpochRecord>(
            "SELECT room_id, membership_revision, active_epoch, status, updated_at
             FROM e2ee_room_epochs WHERE room_id = $1 FOR UPDATE",
        )
        .bind(room_id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("房间 E2EE 状态不存在".to_string()))?;

        let existing = sqlx::query_as::<_, ControlMessageRecord>(
            "SELECT id, room_id, epoch, membership_revision, sender_device_id,
                    recipient_device_id, content_type, envelope, idempotency_key,
                    sequence_no, created_at
             FROM e2ee_control_messages
             WHERE (room_id = $1 AND idempotency_key = $2) OR id = $3
             FOR UPDATE",
        )
        .bind(room_id)
        .bind(input.idempotency_key)
        .bind(input.id)
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;
        if let Some(existing) = existing {
            if existing.room_id == room_id && control_message_matches(&existing, &input) {
                tx.commit().await.map_err(AppError::DatabaseError)?;
                return Ok(existing);
            }
            return Err(AppError::MessageRuntimeConflict(
                "控制消息 id 或 idempotency_key 已绑定其他内容".to_string(),
            ));
        }

        if state.membership_revision != input.membership_revision {
            return Err(AppError::MessageRuntimeConflict(format!(
                "membership revision 冲突，当前为 {}",
                state.membership_revision
            )));
        }
        match input.content_type.as_str() {
            "commit" if input.epoch == state.active_epoch + 1 => {}
            "commit" => {
                return Err(AppError::MessageRuntimeConflict(format!(
                    "Commit epoch 必须为 {}",
                    state.active_epoch + 1
                )))
            }
            "welcome" if state.active_epoch > 0 && input.epoch == state.active_epoch => {}
            "welcome" => {
                return Err(AppError::MessageRuntimeConflict(format!(
                    "Welcome epoch 必须为当前 active epoch {}",
                    state.active_epoch
                )))
            }
            _ => return Err(AppError::ValidationError("控制消息类型无效".to_string())),
        }

        let record = sqlx::query_as::<_, ControlMessageRecord>(
            "INSERT INTO e2ee_control_messages (
                id, room_id, epoch, membership_revision, sender_device_id,
                recipient_device_id, content_type, envelope, idempotency_key
             ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
             RETURNING id, room_id, epoch, membership_revision, sender_device_id,
                       recipient_device_id, content_type, envelope, idempotency_key,
                       sequence_no, created_at",
        )
        .bind(input.id)
        .bind(room_id)
        .bind(input.epoch)
        .bind(input.membership_revision)
        .bind(input.sender_device_id)
        .bind(input.recipient_device_id)
        .bind(&input.content_type)
        .bind(&input.envelope)
        .bind(input.idempotency_key)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        if input.content_type == "commit" {
            sqlx::query(
                "UPDATE e2ee_room_epochs
                 SET active_epoch = $2, status = 'active', updated_at = NOW()
                 WHERE room_id = $1",
            )
            .bind(room_id)
            .bind(input.epoch)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;

            sqlx::query(
                "INSERT INTO e2ee_control_receipts (control_message_id, recipient_device_id)
                 SELECT $1, device.id
                 FROM e2ee_devices AS device
                 JOIN room_members AS member ON member.user_id = device.user_id
                 WHERE member.room_id = $2 AND member.deleted_at IS NULL
                   AND device.status = 'active' AND device.id <> $3
                 ON CONFLICT DO NOTHING",
            )
            .bind(record.id)
            .bind(room_id)
            .bind(input.sender_device_id)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
        } else if let Some(recipient_device_id) = input.recipient_device_id {
            sqlx::query(
                "INSERT INTO e2ee_control_receipts (control_message_id, recipient_device_id)
                 VALUES ($1, $2) ON CONFLICT DO NOTHING",
            )
            .bind(record.id)
            .bind(recipient_device_id)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
        }

        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(record)
    }

    pub async fn list_control_messages(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        device_id: Uuid,
        after_sequence: i64,
        limit: i64,
    ) -> Result<Vec<ControlMessageRecord>, AppError> {
        let mut tx = self.pool.begin().await.map_err(AppError::DatabaseError)?;
        let device_allowed = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS (
                SELECT 1 FROM e2ee_devices AS device
                JOIN room_members AS member ON member.user_id = device.user_id
                WHERE device.id = $1 AND device.user_id = $2 AND device.status = 'active'
                  AND member.room_id = $3 AND member.deleted_at IS NULL
             )",
        )
        .bind(device_id)
        .bind(user_id)
        .bind(room_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;
        if !device_allowed {
            return Err(AppError::Forbidden(
                "接收设备不是当前房间的可信设备".to_string(),
            ));
        }

        let messages = sqlx::query_as::<_, ControlMessageRecord>(
            "SELECT message.id, message.room_id, message.epoch,
                    message.membership_revision, message.sender_device_id,
                    message.recipient_device_id, message.content_type, message.envelope,
                    message.idempotency_key, message.sequence_no, message.created_at
             FROM e2ee_control_messages AS message
             JOIN e2ee_control_receipts AS receipt
               ON receipt.control_message_id = message.id
             WHERE message.room_id = $1 AND receipt.recipient_device_id = $2
               AND message.sequence_no > $3
             ORDER BY message.sequence_no
             LIMIT $4
             FOR UPDATE OF receipt",
        )
        .bind(room_id)
        .bind(device_id)
        .bind(after_sequence)
        .bind(limit)
        .fetch_all(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        if !messages.is_empty() {
            let message_ids = messages
                .iter()
                .map(|message| message.id)
                .collect::<Vec<_>>();
            sqlx::query(
                "UPDATE e2ee_control_receipts
                 SET delivered_at = COALESCE(delivered_at, NOW())
                 WHERE recipient_device_id = $1 AND control_message_id = ANY($2)",
            )
            .bind(device_id)
            .bind(&message_ids)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)?;
        }

        tx.commit().await.map_err(AppError::DatabaseError)?;
        Ok(messages)
    }

    pub async fn consume_control_message(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        device_id: Uuid,
        message_id: Uuid,
    ) -> Result<(), AppError> {
        let result = sqlx::query(
            "UPDATE e2ee_control_receipts AS receipt
             SET consumed_at = COALESCE(consumed_at, NOW())
             FROM e2ee_control_messages AS message, e2ee_devices AS device
             WHERE receipt.control_message_id = message.id
               AND receipt.recipient_device_id = device.id
               AND message.id = $1 AND message.room_id = $2
               AND device.id = $3 AND device.user_id = $4 AND device.status = 'active'
               AND receipt.delivered_at IS NOT NULL
               AND EXISTS (
                 SELECT 1 FROM room_members AS member
                 WHERE member.room_id = $2 AND member.user_id = $4
                   AND member.deleted_at IS NULL
               )",
        )
        .bind(message_id)
        .bind(room_id)
        .bind(device_id)
        .bind(user_id)
        .execute(self.pool)
        .await
        .map_err(AppError::DatabaseError)?;
        if result.rows_affected() == 0 {
            return Err(AppError::NotFound(
                "控制消息未投递、无权消费或不存在".to_string(),
            ));
        }
        Ok(())
    }
}

fn control_message_matches(
    existing: &ControlMessageRecord,
    input: &SubmitControlMessageInput,
) -> bool {
    existing.id == input.id
        && existing.epoch == input.epoch
        && existing.membership_revision == input.membership_revision
        && existing.sender_device_id == input.sender_device_id
        && existing.recipient_device_id == input.recipient_device_id
        && existing.content_type == input.content_type
        && existing.envelope == input.envelope
        && existing.idempotency_key == input.idempotency_key
}

pub async fn validate_application_send_conn(
    connection: &mut PgConnection,
    room_id: Uuid,
    user_id: Uuid,
    sender_device_id: Uuid,
    epoch: i64,
    control_message_id: Uuid,
) -> Result<(), AppError> {
    let device_allowed = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS (
            SELECT 1 FROM e2ee_devices
            WHERE id = $1 AND user_id = $2 AND status = 'active'
         )",
    )
    .bind(sender_device_id)
    .bind(user_id)
    .fetch_one(&mut *connection)
    .await
    .map_err(AppError::DatabaseError)?;
    if !device_allowed {
        return Err(AppError::Forbidden(
            "加密消息发送设备不存在、未批准或已撤销".to_string(),
        ));
    }

    let state = sqlx::query_as::<_, RoomEpochRecord>(
        "SELECT room_id, membership_revision, active_epoch, status, updated_at
         FROM e2ee_room_epochs WHERE room_id = $1 FOR SHARE",
    )
    .bind(room_id)
    .fetch_optional(&mut *connection)
    .await
    .map_err(AppError::DatabaseError)?
    .ok_or_else(|| AppError::MessageRuntimeConflict("房间尚未建立 E2EE epoch".to_string()))?;
    if state.status != "active" {
        return Err(AppError::MessageRuntimeConflict(
            "房间 E2EE 状态未就绪或需要 rekey".to_string(),
        ));
    }
    if state.active_epoch != epoch {
        return Err(AppError::MessageRuntimeConflict(format!(
            "消息 epoch 已过期，当前 active epoch 为 {}",
            state.active_epoch
        )));
    }

    let control_matches = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS (
            SELECT 1 FROM e2ee_control_messages
            WHERE id = $1 AND room_id = $2 AND content_type = 'commit'
              AND epoch = $3 AND membership_revision = $4
         )",
    )
    .bind(control_message_id)
    .bind(room_id)
    .bind(epoch)
    .bind(state.membership_revision)
    .fetch_one(&mut *connection)
    .await
    .map_err(AppError::DatabaseError)?;
    if !control_matches {
        return Err(AppError::MessageRuntimeConflict(
            "control_message_id 未引用当前 epoch 的 Commit".to_string(),
        ));
    }
    Ok(())
}
