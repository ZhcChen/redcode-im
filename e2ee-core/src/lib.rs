use thiserror::Error;

use openmls_memory_storage::MemoryStorage;
use openmls_rust_crypto::RustCrypto;
use openmls_traits::OpenMlsProvider;

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

const MAGIC: &[u8; 4] = b"RCML";
const HEADER_BYTES: usize = 11;
const STATE_MAGIC: &[u8; 4] = b"RCST";
const STATE_HEADER_BYTES: usize = 10;

pub const PROTOCOL_VERSION: u16 = 1;
pub const MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;
pub const STATE_FORMAT_VERSION: u16 = 1;
pub const MAX_STATE_BYTES: usize = 64 * 1024 * 1024;
pub const MAX_STATE_ENTRIES: usize = 100_000;

#[cfg_attr(target_arch = "wasm32", wasm_bindgen)]
pub fn protocol_version() -> u16 {
    PROTOCOL_VERSION
}

#[no_mangle]
pub extern "C" fn rc_e2ee_protocol_version() -> u16 {
    PROTOCOL_VERSION
}

#[derive(Debug, Default)]
pub struct ProtocolProvider {
    crypto: RustCrypto,
    storage: MemoryStorage,
}

impl ProtocolProvider {
    pub fn import_state(encoded: &[u8]) -> Result<Self, StateError> {
        if encoded.len() > MAX_STATE_BYTES {
            return Err(StateError::StateTooLarge);
        }
        if encoded.len() < STATE_HEADER_BYTES || &encoded[..4] != STATE_MAGIC {
            return Err(StateError::InvalidHeader);
        }
        let version = u16::from_be_bytes([encoded[4], encoded[5]]);
        if version != STATE_FORMAT_VERSION {
            return Err(StateError::UnsupportedVersion(version));
        }
        let entry_count =
            u32::from_be_bytes(encoded[6..10].try_into().expect("fixed state header")) as usize;
        if entry_count > MAX_STATE_ENTRIES {
            return Err(StateError::TooManyEntries);
        }

        let mut offset = STATE_HEADER_BYTES;
        let mut values = std::collections::HashMap::with_capacity(entry_count);
        for _ in 0..entry_count {
            let key_length = read_state_length(encoded, &mut offset)?;
            let value_length = read_state_length(encoded, &mut offset)?;
            let key = read_state_field(encoded, &mut offset, key_length)?.to_vec();
            let value = read_state_field(encoded, &mut offset, value_length)?.to_vec();
            if values.insert(key, value).is_some() {
                return Err(StateError::DuplicateKey);
            }
        }
        if offset != encoded.len() {
            return Err(StateError::TrailingBytes);
        }

        Ok(Self {
            crypto: RustCrypto::default(),
            storage: MemoryStorage {
                values: std::sync::RwLock::new(values),
            },
        })
    }

    pub fn export_state(&self) -> Result<Vec<u8>, StateError> {
        let values = self
            .storage
            .values
            .read()
            .map_err(|_| StateError::StorageLockPoisoned)?;
        if values.len() > MAX_STATE_ENTRIES {
            return Err(StateError::TooManyEntries);
        }
        let mut entries: Vec<_> = values.iter().collect();
        entries.sort_unstable_by(|left, right| left.0.cmp(right.0));

        let mut encoded = Vec::new();
        encoded.extend_from_slice(STATE_MAGIC);
        encoded.extend_from_slice(&STATE_FORMAT_VERSION.to_be_bytes());
        encoded.extend_from_slice(&(entries.len() as u32).to_be_bytes());
        for (key, value) in entries {
            let key_length = u32::try_from(key.len()).map_err(|_| StateError::StateTooLarge)?;
            let value_length = u32::try_from(value.len()).map_err(|_| StateError::StateTooLarge)?;
            encoded.extend_from_slice(&key_length.to_be_bytes());
            encoded.extend_from_slice(&value_length.to_be_bytes());
            encoded.extend_from_slice(key);
            encoded.extend_from_slice(value);
            if encoded.len() > MAX_STATE_BYTES {
                return Err(StateError::StateTooLarge);
            }
        }
        Ok(encoded)
    }
}

impl OpenMlsProvider for ProtocolProvider {
    type CryptoProvider = RustCrypto;
    type RandProvider = RustCrypto;
    type StorageProvider = MemoryStorage;

    fn storage(&self) -> &Self::StorageProvider {
        &self.storage
    }

    fn crypto(&self) -> &Self::CryptoProvider {
        &self.crypto
    }

    fn rand(&self) -> &Self::RandProvider {
        &self.crypto
    }
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum StateError {
    #[error("invalid protocol state header")]
    InvalidHeader,
    #[error("unsupported protocol state version {0}")]
    UnsupportedVersion(u16),
    #[error("protocol state is too large")]
    StateTooLarge,
    #[error("protocol state contains too many entries")]
    TooManyEntries,
    #[error("protocol state is truncated")]
    Truncated,
    #[error("protocol state contains trailing bytes")]
    TrailingBytes,
    #[error("protocol state contains a duplicate key")]
    DuplicateKey,
    #[error("protocol state storage lock is poisoned")]
    StorageLockPoisoned,
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen)]
pub fn new_protocol_state() -> Vec<u8> {
    ProtocolProvider::default()
        .export_state()
        .expect("empty protocol state is always serializable")
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen)]
pub fn validate_protocol_state(encoded: &[u8]) -> bool {
    ProtocolProvider::import_state(encoded).is_ok()
}

/// Validates an opaque protocol-state buffer without taking ownership.
///
/// Returns `1` for valid state, `0` for invalid state, and `-1` for an invalid pointer.
///
/// # Safety
/// `data` must reference `length` readable bytes for the duration of this call.
#[no_mangle]
pub unsafe extern "C" fn rc_e2ee_state_validate(data: *const u8, length: usize) -> i32 {
    if data.is_null() {
        return -1;
    }
    let encoded = unsafe { std::slice::from_raw_parts(data, length) };
    i32::from(validate_protocol_state(encoded))
}

/// Writes a new empty protocol state into a caller-owned buffer.
///
/// Returns the required byte length when `output` is null or `capacity` is too small, otherwise
/// returns the number of bytes written. The state contains secret protocol material once used and
/// must be encrypted by the caller before persistence.
///
/// # Safety
/// When non-null, `output` must reference `capacity` writable bytes for the duration of this call.
#[no_mangle]
pub unsafe extern "C" fn rc_e2ee_state_new(output: *mut u8, capacity: usize) -> usize {
    let mut state = new_protocol_state();
    let length = state.len();
    if output.is_null() || capacity < state.len() {
        state.fill(0);
        return length;
    }
    unsafe { std::ptr::copy_nonoverlapping(state.as_ptr(), output, state.len()) };
    state.fill(0);
    length
}

fn read_state_length(encoded: &[u8], offset: &mut usize) -> Result<usize, StateError> {
    let end = offset.checked_add(4).ok_or(StateError::StateTooLarge)?;
    let bytes = encoded.get(*offset..end).ok_or(StateError::Truncated)?;
    *offset = end;
    Ok(u32::from_be_bytes(bytes.try_into().expect("fixed state length")) as usize)
}

fn read_state_field<'a>(
    encoded: &'a [u8],
    offset: &mut usize,
    length: usize,
) -> Result<&'a [u8], StateError> {
    let end = offset
        .checked_add(length)
        .filter(|end| *end <= MAX_STATE_BYTES)
        .ok_or(StateError::StateTooLarge)?;
    let field = encoded.get(*offset..end).ok_or(StateError::Truncated)?;
    *offset = end;
    Ok(field)
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
