use redcode_e2ee_core::{Envelope, EnvelopeKind, MlsSession, MlsSessionError, ProtocolProvider};

#[test]
fn removed_member_is_excluded_while_remaining_members_advance_epoch() {
    let alice = MlsSession::initialize(b"alice-device-1").expect("initialize alice");
    let bob = MlsSession::initialize(b"bob-device-1").expect("initialize bob");
    let carol = MlsSession::initialize(b"carol-device-1").expect("initialize carol");
    let mut alice_session = MlsSession::import(&alice.state).expect("import alice");
    let mut bob_session = MlsSession::import(&bob.state).expect("import bob");
    let mut carol_session = MlsSession::import(&carol.state).expect("import carol");
    let group_id = b"room-direct-removal";

    alice_session.create_group(group_id).expect("create group");
    let bob_added = alice_session
        .add_member(group_id, &bob.key_package)
        .expect("add bob");
    assert_eq!(bob_added.epoch, 1);
    let (_, bob_epoch) = bob_session
        .join_group(&bob_added.welcome)
        .expect("join bob");
    assert_eq!(bob_epoch, 1);
    let carol_added = alice_session
        .add_member(group_id, &carol.key_package)
        .expect("add carol");
    assert_eq!(carol_added.epoch, 2);
    assert_eq!(
        alice_session.list_members(group_id).expect("list members"),
        vec![
            b"alice-device-1".to_vec(),
            b"bob-device-1".to_vec(),
            b"carol-device-1".to_vec(),
        ]
    );
    let (_, carol_epoch) = carol_session
        .join_group(&carol_added.welcome)
        .expect("join carol");
    assert_eq!(carol_epoch, 2);

    let removed = alice_session
        .remove_member(group_id, b"bob-device-1")
        .expect("remove bob");
    assert_eq!(removed.epoch, 3);
    assert_eq!(
        alice_session.list_members(group_id).expect("list members"),
        vec![b"alice-device-1".to_vec(), b"carol-device-1".to_vec()]
    );
    assert_eq!(
        Envelope::decode(&removed.commit).unwrap().kind(),
        EnvelopeKind::Commit
    );

    let (carol_state, carol_epoch) = carol_session
        .process_commit(group_id, &removed.commit)
        .expect("carol processes removal commit");
    assert_eq!(carol_epoch, 3);
    let mut carol_session = MlsSession::import(&carol_state).expect("restore carol");

    // 被移除成员即使持有旧状态，也无法消费移除 Commit。
    assert!(matches!(
        bob_session.process_commit(group_id, &removed.commit),
        Err(MlsSessionError::Operation(_))
    ));

    let (ciphertext, message_epoch, _) = alice_session
        .encrypt(group_id, b"after removal")
        .expect("encrypt alice");
    assert_eq!(message_epoch, 3);
    let decrypted = carol_session
        .decrypt(group_id, &ciphertext)
        .expect("carol decrypts after removal");
    assert_eq!(decrypted.plaintext, b"after removal");
    assert!(matches!(
        bob_session.decrypt(group_id, &ciphertext),
        Err(MlsSessionError::Operation(_))
    ));
}

#[test]
fn remove_member_rejects_unknown_identity() {
    let alice = MlsSession::initialize(b"alice-device-1").expect("initialize alice");
    let mut alice_session = MlsSession::import(&alice.state).expect("import alice");
    alice_session
        .create_group(b"room-unknown")
        .expect("create group");
    assert!(matches!(
        alice_session.remove_member(b"room-unknown", b"missing-device"),
        Err(MlsSessionError::MemberNotFound)
    ));
}

#[test]
fn device_approval_signature_verifies_with_openmls_crypto() {
    use openmls::prelude::Ciphersuite;
    use openmls_traits::crypto::OpenMlsCrypto;
    use openmls_traits::OpenMlsProvider;

    let alice = MlsSession::initialize(b"alice-device-1").expect("initialize alice");
    let session = MlsSession::import(&alice.state).expect("import alice");
    let payload = b"redcode-im/e2ee/device-approval/v1\0fixture";
    let signature = session
        .sign_device_approval(payload)
        .expect("sign device approval");
    assert_eq!(signature.len(), 64);

    let provider = ProtocolProvider::default();
    let public_key = alice.public_material.approval_public_key;
    provider
        .crypto()
        .verify_signature(
            Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519.signature_algorithm(),
            payload,
            &public_key,
            &signature,
        )
        .expect("verify device approval signature");

    assert!(provider
        .crypto()
        .verify_signature(
            Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519.signature_algorithm(),
            b"tampered payload",
            &public_key,
            &signature,
        )
        .is_err());
}
