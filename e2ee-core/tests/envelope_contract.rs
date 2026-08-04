use redcode_e2ee_core::{Envelope, EnvelopeError, EnvelopeKind, PROTOCOL_VERSION};

#[test]
fn envelope_round_trips_with_an_explicit_version_and_kind() {
    let encoded = Envelope::new(EnvelopeKind::Application, b"ciphertext".to_vec()).encode();
    let decoded = Envelope::decode(&encoded).expect("valid envelope");

    assert_eq!(decoded.version(), PROTOCOL_VERSION);
    assert_eq!(decoded.kind(), EnvelopeKind::Application);
    assert_eq!(decoded.payload(), b"ciphertext");
}

#[test]
fn envelope_rejects_unknown_versions_and_truncated_payloads() {
    let mut unknown_version = Envelope::new(EnvelopeKind::Commit, vec![1, 2, 3]).encode();
    unknown_version[4..6].copy_from_slice(&(PROTOCOL_VERSION + 1).to_be_bytes());
    assert_eq!(
        Envelope::decode(&unknown_version),
        Err(EnvelopeError::UnsupportedVersion(PROTOCOL_VERSION + 1)),
    );

    let mut truncated = Envelope::new(EnvelopeKind::Welcome, vec![1, 2, 3]).encode();
    truncated.pop();
    assert_eq!(
        Envelope::decode(&truncated),
        Err(EnvelopeError::InvalidLength)
    );
}

#[test]
fn envelope_rejects_unknown_kinds_and_oversized_payloads() {
    let mut unknown_kind = Envelope::new(EnvelopeKind::Application, vec![]).encode();
    unknown_kind[6] = 0xff;
    assert_eq!(
        Envelope::decode(&unknown_kind),
        Err(EnvelopeError::UnknownKind(0xff))
    );

    let oversized = vec![0; redcode_e2ee_core::MAX_PAYLOAD_BYTES + 1];
    assert_eq!(
        Envelope::try_new(EnvelopeKind::Application, oversized),
        Err(EnvelopeError::PayloadTooLarge),
    );
}
