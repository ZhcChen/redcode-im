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
    (SELECT COALESCE(string_agg(md5(identity_row::text), '' ORDER BY user_id), '')
      FROM e2ee_account_identities AS identity_row) AS identities_digest,
    (SELECT COALESCE(string_agg(md5(device_row::text), '' ORDER BY id), '')
      FROM e2ee_devices AS device_row) AS devices_digest,
    (SELECT COALESCE(string_agg(md5(package_row::text), '' ORDER BY id), '')
      FROM e2ee_key_packages AS package_row) AS key_packages_digest,
    (SELECT COALESCE(string_agg(md5(epoch_row::text), '' ORDER BY room_id), '')
      FROM e2ee_room_epochs AS epoch_row) AS epochs_digest,
    (SELECT COALESCE(string_agg(md5(message_row::text), '' ORDER BY id), '')
      FROM e2ee_control_messages AS message_row) AS control_messages_digest,
    (SELECT COALESCE(string_agg(md5(receipt_row::text), ''
      ORDER BY control_message_id, recipient_device_id), '')
      FROM e2ee_control_receipts AS receipt_row) AS control_receipts_digest,
    (SELECT COALESCE(string_agg(md5(message_row::text), '' ORDER BY id), '')
      FROM messages AS message_row WHERE encrypted_content IS NOT NULL) AS messages_digest,
    (SELECT COALESCE(string_agg(md5(attachment_row::text), '' ORDER BY room_id, object_key), '')
      FROM message_attachment_commits AS attachment_row) AS attachments_digest
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
