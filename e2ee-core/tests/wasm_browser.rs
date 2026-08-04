#![cfg(target_arch = "wasm32")]

use openmls::prelude::tls_codec::Deserialize;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_memory_storage::MemoryStorage;
use openmls_rust_crypto::RustCrypto;
use openmls_traits::OpenMlsProvider;
use wasm_bindgen_test::*;

wasm_bindgen_test_configure!(run_in_browser);

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

#[derive(Debug, Default)]
struct BrowserProvider {
    crypto: RustCrypto,
    storage: MemoryStorage,
}

impl OpenMlsProvider for BrowserProvider {
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

struct BrowserDevice {
    provider: BrowserProvider,
    credential: CredentialWithKey,
    signer: SignatureKeyPair,
}

impl BrowserDevice {
    fn new(identity: &str) -> Self {
        let provider = BrowserProvider::default();
        let signer =
            SignatureKeyPair::new(CIPHERSUITE.signature_algorithm()).expect("create signing key");
        signer.store(provider.storage()).expect("store signing key");
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

fn as_message_in(message: MlsMessageOut) -> MlsMessageIn {
    MlsMessageIn::tls_deserialize_exact(message.to_bytes().expect("serialize MLS message"))
        .expect("deserialize MLS message")
}

#[wasm_bindgen_test]
fn openmls_group_exchanges_an_application_message_in_chrome() {
    let alice = BrowserDevice::new("alice-browser-device");
    let bob = BrowserDevice::new("bob-browser-device");
    let mut alice_group = MlsGroup::new_with_group_id(
        &alice.provider,
        &alice.signer,
        &MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .use_ratchet_tree_extension(true)
            .build(),
        GroupId::from_slice(b"redcode-browser-room"),
        alice.credential.clone(),
    )
    .expect("create browser group");

    let (_, welcome, _) = alice_group
        .add_members(
            &alice.provider,
            &alice.signer,
            &[bob.key_package().key_package().clone()],
        )
        .expect("add browser member");
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge browser add commit");

    let welcome = match as_message_in(welcome).extract() {
        MlsMessageBodyIn::Welcome(welcome) => welcome,
        _ => panic!("expected welcome message"),
    };
    let mut bob_group = StagedWelcome::new_from_welcome(
        &bob.provider,
        &MlsGroupJoinConfig::builder()
            .use_ratchet_tree_extension(true)
            .build(),
        welcome,
        None,
    )
    .expect("stage browser welcome")
    .into_group(&bob.provider)
    .expect("join browser group");

    let ciphertext = alice_group
        .create_message(
            &alice.provider,
            &alice.signer,
            b"ciphertext created in Chrome",
        )
        .expect("create browser application message");
    let processed = bob_group
        .process_message(
            &bob.provider,
            as_message_in(ciphertext)
                .try_into_protocol_message()
                .expect("application protocol message"),
        )
        .expect("process browser application message");
    let ProcessedMessageContent::ApplicationMessage(application) = processed.into_content() else {
        panic!("expected application message");
    };
    assert_eq!(application.into_bytes(), b"ciphertext created in Chrome");
}
