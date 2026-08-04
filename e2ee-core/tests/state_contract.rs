use openmls_traits::OpenMlsProvider;
use redcode_e2ee_core::{
    new_protocol_state, validate_protocol_state, ProtocolProvider, StateError, STATE_FORMAT_VERSION,
};

#[test]
fn empty_state_round_trips_with_explicit_version() {
    let encoded = new_protocol_state();

    assert_eq!(&encoded[..4], b"RCST");
    assert_eq!(
        u16::from_be_bytes([encoded[4], encoded[5]]),
        STATE_FORMAT_VERSION
    );
    assert!(validate_protocol_state(&encoded));
    assert_eq!(
        ProtocolProvider::import_state(&encoded)
            .unwrap()
            .export_state()
            .unwrap(),
        encoded
    );
}

#[test]
fn state_export_is_deterministic_and_preserves_openmls_storage() {
    let provider = ProtocolProvider::default();
    provider.storage().values.write().unwrap().extend([
        (b"z-key".to_vec(), vec![3]),
        (b"a-key".to_vec(), vec![1, 2]),
    ]);

    let first = provider.export_state().unwrap();
    let second = provider.export_state().unwrap();
    let restored = ProtocolProvider::import_state(&first).unwrap();

    assert_eq!(first, second);
    assert_eq!(restored.export_state().unwrap(), first);
    assert_eq!(
        restored
            .storage()
            .values
            .read()
            .unwrap()
            .get(b"a-key".as_slice()),
        Some(&vec![1, 2])
    );
}

#[test]
fn state_import_rejects_unknown_versions_truncation_duplicates_and_trailing_bytes() {
    let mut unknown_version = new_protocol_state();
    unknown_version[4..6].copy_from_slice(&(STATE_FORMAT_VERSION + 1).to_be_bytes());
    assert_eq!(
        ProtocolProvider::import_state(&unknown_version).unwrap_err(),
        StateError::UnsupportedVersion(STATE_FORMAT_VERSION + 1)
    );

    let mut truncated = new_protocol_state();
    truncated[6..10].copy_from_slice(&1_u32.to_be_bytes());
    assert_eq!(
        ProtocolProvider::import_state(&truncated).unwrap_err(),
        StateError::Truncated
    );

    let duplicate = state_with_entries(&[(b"same", b"one"), (b"same", b"two")]);
    assert_eq!(
        ProtocolProvider::import_state(&duplicate).unwrap_err(),
        StateError::DuplicateKey
    );

    let mut trailing = new_protocol_state();
    trailing.push(0);
    assert_eq!(
        ProtocolProvider::import_state(&trailing).unwrap_err(),
        StateError::TrailingBytes
    );
}

#[test]
fn c_abi_state_validation_matches_rust_validation() {
    let required = unsafe { redcode_e2ee_core::rc_e2ee_state_new(std::ptr::null_mut(), 0) };
    let mut state = vec![0_u8; required];
    let written = unsafe { redcode_e2ee_core::rc_e2ee_state_new(state.as_mut_ptr(), state.len()) };
    assert_eq!(written, required);
    assert_eq!(state, new_protocol_state());
    let result = unsafe { redcode_e2ee_core::rc_e2ee_state_validate(state.as_ptr(), state.len()) };
    assert_eq!(result, 1);

    let invalid = unsafe { redcode_e2ee_core::rc_e2ee_state_validate([0_u8].as_ptr(), 1) };
    assert_eq!(invalid, 0);
    let null = unsafe { redcode_e2ee_core::rc_e2ee_state_validate(std::ptr::null(), 0) };
    assert_eq!(null, -1);
}

fn state_with_entries(entries: &[(&[u8], &[u8])]) -> Vec<u8> {
    let mut encoded = b"RCST".to_vec();
    encoded.extend_from_slice(&STATE_FORMAT_VERSION.to_be_bytes());
    encoded.extend_from_slice(&(entries.len() as u32).to_be_bytes());
    for (key, value) in entries {
        encoded.extend_from_slice(&(key.len() as u32).to_be_bytes());
        encoded.extend_from_slice(&(value.len() as u32).to_be_bytes());
        encoded.extend_from_slice(key);
        encoded.extend_from_slice(value);
    }
    encoded
}
