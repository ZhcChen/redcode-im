use serde::{Deserialize, Serialize};
use uuid::Uuid;

const MAGIC: &[u8; 4] = b"RCML";
const HEADER_BYTES: usize = 11;

pub const PROTOCOL_VERSION: u16 = 1;
pub const MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;
pub const ENCRYPTED_MESSAGE_PLACEHOLDER: &str = "[加密消息]";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum EncryptionProtocol {
    Mls,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum EncryptedContentType {
    Application,
    Commit,
    Welcome,
}

impl EncryptedContentType {
    fn wire_kind(self) -> u8 {
        match self {
            Self::Application => 1,
            Self::Commit => 2,
            Self::Welcome => 3,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct EncryptionMetadata {
    pub protocol: EncryptionProtocol,
    pub version: u16,
    pub epoch: u64,
    pub sender_device_id: Uuid,
    pub content_type: EncryptedContentType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub control_message_id: Option<Uuid>,
}

pub fn validate_envelope(
    encoded: &[u8],
    metadata: &EncryptionMetadata,
) -> Result<(), &'static str> {
    if encoded.len() < HEADER_BYTES {
        return Err("encrypted_content envelope 长度无效");
    }
    if &encoded[..4] != MAGIC {
        return Err("encrypted_content envelope magic 无效");
    }

    let version = u16::from_be_bytes([encoded[4], encoded[5]]);
    if version != PROTOCOL_VERSION || metadata.version != PROTOCOL_VERSION {
        return Err("不支持的 E2EE 协议版本");
    }
    if encoded[6] != metadata.content_type.wire_kind() {
        return Err("envelope kind 与 encryption_metadata.content_type 不一致");
    }
    let payload_len =
        u32::from_be_bytes([encoded[7], encoded[8], encoded[9], encoded[10]]) as usize;
    if payload_len > MAX_PAYLOAD_BYTES {
        return Err("encrypted_content payload 过大");
    }
    if encoded.len() != HEADER_BYTES + payload_len {
        return Err("encrypted_content envelope 长度无效");
    }
    if metadata.epoch == 0 {
        return Err("encryption_metadata.epoch 必须大于 0");
    }
    if metadata.sender_device_id.is_nil() {
        return Err("encryption_metadata.sender_device_id 无效");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn envelope(kind: u8, version: u16, payload: &[u8]) -> Vec<u8> {
        let mut encoded = b"RCML".to_vec();
        encoded.extend_from_slice(&version.to_be_bytes());
        encoded.push(kind);
        encoded.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        encoded.extend_from_slice(payload);
        encoded
    }

    fn metadata() -> EncryptionMetadata {
        EncryptionMetadata {
            protocol: EncryptionProtocol::Mls,
            version: PROTOCOL_VERSION,
            epoch: 1,
            sender_device_id: Uuid::from_u128(1),
            content_type: EncryptedContentType::Application,
            control_message_id: None,
        }
    }

    #[test]
    fn matching_envelope_and_metadata_are_accepted() {
        assert_eq!(
            validate_envelope(&envelope(1, 1, b"ciphertext"), &metadata()),
            Ok(())
        );
    }

    #[test]
    fn unknown_versions_kinds_and_lengths_are_rejected() {
        assert!(validate_envelope(&envelope(1, 2, b"ciphertext"), &metadata()).is_err());
        assert!(validate_envelope(&envelope(2, 1, b"ciphertext"), &metadata()).is_err());

        let mut truncated = envelope(1, 1, b"ciphertext");
        truncated.pop();
        assert!(validate_envelope(&truncated, &metadata()).is_err());
    }

    #[test]
    fn zero_epoch_is_rejected() {
        let mut invalid = metadata();
        invalid.epoch = 0;
        assert!(validate_envelope(&envelope(1, 1, b"ciphertext"), &invalid).is_err());
    }

    #[test]
    fn nil_sender_device_is_rejected() {
        let mut invalid = metadata();
        invalid.sender_device_id = Uuid::nil();
        assert!(validate_envelope(&envelope(1, 1, b"ciphertext"), &invalid).is_err());
    }
}
