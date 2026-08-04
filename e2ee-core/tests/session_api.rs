use redcode_e2ee_core::{Envelope, EnvelopeKind, MlsSession, MlsSessionError};

#[test]
fn direct_session_bootstraps_exchanges_and_recovers() {
    let alice = MlsSession::initialize(b"alice-device-1").expect("initialize alice");
    let bob = MlsSession::initialize(b"bob-device-1").expect("initialize bob");
    let mut alice_session = MlsSession::import(&alice.state).expect("import alice");
    let mut bob_session = MlsSession::import(&bob.state).expect("import bob");
    let group_id = b"room-direct-1";

    alice_session.create_group(group_id).expect("create group");
    let added = alice_session
        .add_member(group_id, &bob.key_package)
        .expect("add bob");
    assert_eq!(added.epoch, 1);
    assert_eq!(
        Envelope::decode(&added.commit).unwrap().kind(),
        EnvelopeKind::Commit
    );
    assert_eq!(
        Envelope::decode(&added.welcome).unwrap().kind(),
        EnvelopeKind::Welcome
    );
    let (_, bob_epoch) = bob_session.join_group(&added.welcome).expect("join bob");
    assert_eq!(bob_epoch, added.epoch);

    let (ciphertext, message_epoch, _) = alice_session
        .encrypt(group_id, b"hello from alice")
        .expect("encrypt alice");
    assert_eq!(message_epoch, added.epoch);
    let decrypted = bob_session
        .decrypt(group_id, &ciphertext)
        .expect("decrypt bob");
    assert_eq!(decrypted.plaintext, b"hello from alice");

    let mut restored_bob = MlsSession::import(&decrypted.state).expect("restore bob");
    let (reply, _, _) = restored_bob
        .encrypt(group_id, b"reply after restart")
        .expect("encrypt reply");
    assert_eq!(
        alice_session.decrypt(group_id, &reply).unwrap().plaintext,
        b"reply after restart"
    );

    assert!(matches!(
        bob_session.decrypt(group_id, &ciphertext),
        Err(MlsSessionError::Operation(_))
    ));
}

#[test]
fn session_rejects_uninitialized_state_and_wrong_envelope_kind() {
    let empty = redcode_e2ee_core::new_protocol_state();
    assert!(matches!(
        MlsSession::import(&empty),
        Err(MlsSessionError::NotInitialized)
    ));

    let alice = MlsSession::initialize(b"alice-device-1").unwrap();
    let mut session = MlsSession::import(&alice.state).unwrap();
    session.create_group(b"room-1").unwrap();
    let commit = Envelope::new(EnvelopeKind::Commit, vec![1, 2, 3]).encode();
    assert!(matches!(
        session.decrypt(b"room-1", &commit),
        Err(MlsSessionError::UnexpectedMessage)
    ));
}
