use thiserror::Error;

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

const MAGIC: &[u8; 4] = b"RCML";
const HEADER_BYTES: usize = 11;

pub const PROTOCOL_VERSION: u16 = 1;
pub const MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;

#[cfg_attr(target_arch = "wasm32", wasm_bindgen)]
pub fn protocol_version() -> u16 {
    PROTOCOL_VERSION
}

#[no_mangle]
pub extern "C" fn rc_e2ee_protocol_version() -> u16 {
    PROTOCOL_VERSION
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum EnvelopeKind {
    Application = 1,
    Commit = 2,
    Welcome = 3,
}

impl TryFrom<u8> for EnvelopeKind {
    type Error = EnvelopeError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            1 => Ok(Self::Application),
            2 => Ok(Self::Commit),
            3 => Ok(Self::Welcome),
            other => Err(EnvelopeError::UnknownKind(other)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Envelope {
    version: u16,
    kind: EnvelopeKind,
    payload: Vec<u8>,
}

impl Envelope {
    pub fn new(kind: EnvelopeKind, payload: Vec<u8>) -> Self {
        Self::try_new(kind, payload).expect("envelope payload exceeds the protocol limit")
    }

    pub fn try_new(kind: EnvelopeKind, payload: Vec<u8>) -> Result<Self, EnvelopeError> {
        if payload.len() > MAX_PAYLOAD_BYTES {
            return Err(EnvelopeError::PayloadTooLarge);
        }
        Ok(Self {
            version: PROTOCOL_VERSION,
            kind,
            payload,
        })
    }

    pub fn decode(encoded: &[u8]) -> Result<Self, EnvelopeError> {
        if encoded.len() < HEADER_BYTES {
            return Err(EnvelopeError::InvalidLength);
        }
        if &encoded[..4] != MAGIC {
            return Err(EnvelopeError::InvalidMagic);
        }

        let version = u16::from_be_bytes([encoded[4], encoded[5]]);
        if version != PROTOCOL_VERSION {
            return Err(EnvelopeError::UnsupportedVersion(version));
        }
        let kind = EnvelopeKind::try_from(encoded[6])?;
        let payload_len =
            u32::from_be_bytes([encoded[7], encoded[8], encoded[9], encoded[10]]) as usize;
        if payload_len > MAX_PAYLOAD_BYTES {
            return Err(EnvelopeError::PayloadTooLarge);
        }
        if encoded.len() != HEADER_BYTES + payload_len {
            return Err(EnvelopeError::InvalidLength);
        }

        Ok(Self {
            version,
            kind,
            payload: encoded[HEADER_BYTES..].to_vec(),
        })
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut encoded = Vec::with_capacity(HEADER_BYTES + self.payload.len());
        encoded.extend_from_slice(MAGIC);
        encoded.extend_from_slice(&self.version.to_be_bytes());
        encoded.push(self.kind as u8);
        encoded.extend_from_slice(&(self.payload.len() as u32).to_be_bytes());
        encoded.extend_from_slice(&self.payload);
        encoded
    }

    pub fn version(&self) -> u16 {
        self.version
    }

    pub fn kind(&self) -> EnvelopeKind {
        self.kind
    }

    pub fn payload(&self) -> &[u8] {
        &self.payload
    }
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum EnvelopeError {
    #[error("invalid envelope magic")]
    InvalidMagic,
    #[error("invalid envelope length")]
    InvalidLength,
    #[error("unsupported protocol version {0}")]
    UnsupportedVersion(u16),
    #[error("unknown envelope kind {0}")]
    UnknownKind(u8),
    #[error("envelope payload is too large")]
    PayloadTooLarge,
}
