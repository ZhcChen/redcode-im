use std::io::Cursor;

use openmls::prelude::tls_codec::Deserialize;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_memory_storage::MemoryStorage;
use openmls_rust_crypto::RustCrypto;
use openmls_traits::OpenMlsProvider;

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

#[derive(Debug, Default)]
struct TestProvider {
    crypto: RustCrypto,
    storage: MemoryStorage,
}

impl TestProvider {
    fn export_state(&self) -> Vec<u8> {
        let mut state = Vec::new();
        self.storage
            .serialize(&mut state)
            .expect("serialize provider state");
        state
    }

    fn import_state(state: &[u8]) -> Self {
        Self {
            crypto: RustCrypto::default(),
            storage: MemoryStorage::deserialize(&mut Cursor::new(state))
                .expect("deserialize provider state"),
        }
    }
}

impl OpenMlsProvider for TestProvider {
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

struct Device {
    provider: TestProvider,
    credential: CredentialWithKey,
    signer: SignatureKeyPair,
}

impl Device {
    fn new(identity: &str) -> Self {
        let provider = TestProvider::default();
        let signer =
            SignatureKeyPair::new(CIPHERSUITE.signature_algorithm()).expect("create signature key");
        signer
            .store(provider.storage())
            .expect("store signature key");
        let credential = CredentialWithKey {
            credential: BasicCredential::new(identity.as_bytes().to_vec()).into(),
            signature_key: signer.to_public_vec().into(),
        };
        Self {
            provider,
            credential,
            signer,
        }
    }

    fn key_package(&self) -> KeyPackageBundle {
        KeyPackage::builder()
            .build(
                CIPHERSUITE,
                &self.provider,
                &self.signer,
                self.credential.clone(),
            )
            .expect("create key package")
    }
}

fn create_group(owner: &Device, group_id: &[u8]) -> MlsGroup {
    MlsGroup::new_with_group_id(
        &owner.provider,
        &owner.signer,
        &MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .use_ratchet_tree_extension(true)
            .build(),
        GroupId::from_slice(group_id),
        owner.credential.clone(),
    )
    .expect("create group")
}

fn add_member(
    owner: &Device,
    group: &mut MlsGroup,
    member: &Device,
) -> (MlsMessageOut, MlsMessageOut) {
    let (commit, welcome, _) = group
        .add_members(
            &owner.provider,
            &owner.signer,
            &[member.key_package().key_package().clone()],
        )
        .expect("add member");
    (commit, welcome)
}

fn as_message_in(message: MlsMessageOut) -> MlsMessageIn {
    let bytes = message.to_bytes().expect("serialize MLS message");
    MlsMessageIn::tls_deserialize_exact(bytes).expect("deserialize MLS message")
}

fn as_welcome(message: MlsMessageOut) -> Welcome {
    match as_message_in(message).extract() {
        MlsMessageBodyIn::Welcome(welcome) => welcome,
        _ => panic!("expected welcome message"),
    }
}

fn as_protocol_message(message: MlsMessageOut) -> ProtocolMessage {
    as_message_in(message)
        .try_into_protocol_message()
        .expect("protocol message")
}

fn join_group(device: &Device, welcome: MlsMessageOut) -> MlsGroup {
    StagedWelcome::new_from_welcome(
        &device.provider,
        &MlsGroupJoinConfig::builder()
            .use_ratchet_tree_extension(true)
            .build(),
        as_welcome(welcome),
        None,
    )
    .expect("stage welcome")
    .into_group(&device.provider)
    .expect("join group")
}

fn process_application(device: &Device, group: &mut MlsGroup, message: MlsMessageOut) -> Vec<u8> {
    let processed = group
        .process_message(&device.provider, as_protocol_message(message))
        .expect("process application message");
    match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(application) => application.into_bytes(),
        _ => panic!("expected application message"),
    }
}

fn merge_commit(device: &Device, group: &mut MlsGroup, commit: MlsMessageOut) {
    let processed = group
        .process_message(&device.provider, as_protocol_message(commit))
        .expect("process commit");
    let ProcessedMessageContent::StagedCommitMessage(staged) = processed.into_content() else {
        panic!("expected staged commit");
    };
    group
        .merge_staged_commit(&device.provider, *staged)
        .expect("merge staged commit");
}

#[test]
fn two_devices_exchange_messages_and_resume_from_exported_state() {
    let alice = Device::new("alice-device-1");
    let bob = Device::new("bob-device-1");
    let mut alice_group = create_group(&alice, b"redcode-direct-room");
    let (_, welcome) = add_member(&alice, &mut alice_group, &bob);
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge add commit");
    let mut bob_group = join_group(&bob, welcome);

    let first = alice_group
        .create_message(&alice.provider, &alice.signer, b"hello from native")
        .expect("encrypt first message");
    assert_eq!(
        process_application(&bob, &mut bob_group, first),
        b"hello from native"
    );

    let state = bob.provider.export_state();
    let restored_provider = TestProvider::import_state(&state);
    let mut restored_group = MlsGroup::load(restored_provider.storage(), bob_group.group_id())
        .expect("load persisted group")
        .expect("persisted group exists");

    let second = alice_group
        .create_message(&alice.provider, &alice.signer, b"hello after restart")
        .expect("encrypt second message");
    let duplicate = second.clone();
    let processed = restored_group
        .process_message(&restored_provider, as_protocol_message(second))
        .expect("decrypt after restart");
    let ProcessedMessageContent::ApplicationMessage(application) = processed.into_content() else {
        panic!("expected application message");
    };
    assert_eq!(application.into_bytes(), b"hello after restart");
    assert!(restored_group
        .process_message(&restored_provider, as_protocol_message(duplicate),)
        .is_err());
}

#[test]
fn removed_member_cannot_decrypt_messages_from_the_new_epoch() {
    let alice = Device::new("alice-device-1");
    let bob = Device::new("bob-device-1");
    let charlie = Device::new("charlie-device-1");
    let mut alice_group = create_group(&alice, b"redcode-group-room");

    let (_, bob_welcome) = add_member(&alice, &mut alice_group, &bob);
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge bob add");
    let mut bob_group = join_group(&bob, bob_welcome);

    let (charlie_commit, charlie_welcome) = add_member(&alice, &mut alice_group, &charlie);
    merge_commit(&bob, &mut bob_group, charlie_commit);
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge charlie add");
    let mut charlie_group = join_group(&charlie, charlie_welcome);

    let charlie_index = alice_group
        .members()
        .find(|member| member.credential.serialized_content() == b"charlie-device-1")
        .map(|member| member.index)
        .expect("charlie leaf index");
    let (remove_commit, _, _) = alice_group
        .remove_members(&alice.provider, &alice.signer, &[charlie_index])
        .expect("remove charlie");
    merge_commit(&bob, &mut bob_group, remove_commit);
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge remove commit");

    let after_removal = alice_group
        .create_message(&alice.provider, &alice.signer, b"new epoch secret")
        .expect("encrypt after removal");
    assert!(charlie_group
        .process_message(&charlie.provider, as_protocol_message(after_removal),)
        .is_err());
}
