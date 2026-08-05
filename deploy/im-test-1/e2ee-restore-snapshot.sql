WITH component_digests AS (
  SELECT
    (SELECT COUNT(*) FROM e2ee_account_identities) AS identities,
    (SELECT COUNT(*) FROM e2ee_devices) AS devices,
    (SELECT COUNT(*) FROM e2ee_key_packages) AS key_packages,
    (SELECT COUNT(*) FROM e2ee_room_epochs) AS room_epochs,
    (SELECT COUNT(*) FROM e2ee_control_messages) AS control_messages,
    (SELECT COUNT(*) FROM e2ee_control_receipts) AS control_receipts,
    (SELECT COUNT(*) FROM messages WHERE encrypted_content IS NOT NULL) AS encrypted_messages,
    (SELECT COUNT(*) FROM message_attachment_commits) AS attachment_commits,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', user_id,
      encode(root_public_key, 'hex'), encode(root_fingerprint, 'hex'), protocol_version)), ''
      ORDER BY user_id), '') FROM e2ee_account_identities) AS identities_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', id, user_id, status,
      encode(credential_fingerprint, 'hex'), protocol_version)), '' ORDER BY id), '')
      FROM e2ee_devices) AS devices_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', id, device_id,
      encode(package_ref, 'hex'), encode(key_package, 'hex'), consumed_at IS NOT NULL,
      consumed_by_device_id)), '' ORDER BY id), '') FROM e2ee_key_packages) AS key_packages_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', room_id, membership_revision,
      active_epoch, status)), '' ORDER BY room_id), '') FROM e2ee_room_epochs) AS epochs_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', id, room_id, epoch,
      membership_revision, sender_device_id, recipient_device_id, content_type,
      encode(envelope, 'hex'), idempotency_key, sequence_no)), '' ORDER BY id), '')
      FROM e2ee_control_messages) AS control_messages_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', control_message_id,
      recipient_device_id, delivered_at IS NOT NULL, consumed_at IS NOT NULL)), ''
      ORDER BY control_message_id, recipient_device_id), '')
      FROM e2ee_control_receipts) AS control_receipts_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', id, room_id, sender_id,
      encode(encrypted_content, 'hex'), encryption_metadata::text)), '' ORDER BY id), '')
      FROM messages WHERE encrypted_content IS NOT NULL) AS messages_digest,
    (SELECT COALESCE(string_agg(md5(concat_ws(':', room_id, object_key, uploaded_by,
      file_size, confirmed_at IS NOT NULL)), '' ORDER BY room_id, object_key), '')
      FROM message_attachment_commits) AS attachments_digest
), snapshot AS (
  SELECT jsonb_build_object(
    'identities', identities,
    'devices', devices,
    'key_packages', key_packages,
    'room_epochs', room_epochs,
    'control_messages', control_messages,
    'control_receipts', control_receipts,
    'encrypted_messages', encrypted_messages,
    'attachment_commits', attachment_commits,
    'digest', md5(concat_ws('|', identities_digest, devices_digest, key_packages_digest,
      epochs_digest, control_messages_digest, control_receipts_digest, messages_digest,
      attachments_digest))
  ) AS value
  FROM component_digests
)
SELECT value::text FROM snapshot;
