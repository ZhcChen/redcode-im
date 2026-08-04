#![cfg(target_arch = "wasm32")]

use base64::{engine::general_purpose::STANDARD, Engine};
use openmls::prelude::tls_codec::Deserialize;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_traits::OpenMlsProvider;
use redcode_e2ee_core::ProtocolProvider;
use redcode_e2ee_core::{new_protocol_state, validate_protocol_state};
use wasm_bindgen_futures::JsFuture;
use wasm_bindgen_test::*;
use web_sys::{Request, RequestInit};

#[allow(dead_code)]
#[path = "../interop/fixture.rs"]
mod fixture_format;

use fixture_format::CrossRuntimeFixture;

wasm_bindgen_test_configure!(run_in_browser);

#[wasm_bindgen_test]
fn wasm_exports_versioned_protocol_state_contract() {
    let state = new_protocol_state();
    assert!(validate_protocol_state(&state));
    assert_eq!(&state[..4], b"RCST");

    let mut damaged = state;
    damaged[0] = 0;
    assert!(!validate_protocol_state(&damaged));
}

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

struct BrowserDevice {
    provider: ProtocolProvider,
    credential: CredentialWithKey,
    signer: SignatureKeyPair,
}

impl BrowserDevice {
    fn new(identity: &str) -> Self {
        let provider = ProtocolProvider::default();
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

#[wasm_bindgen_test]
async fn wasm_resumes_native_state_and_exports_the_advanced_state() {
    let fixture =
        CrossRuntimeFixture::decode(include_bytes!("../interop/fixtures/native_to_wasm.bin"))
            .expect("decode native fixture");
    let provider = ProtocolProvider::import_state(&fixture.provider_state)
        .expect("deserialize native provider state");
    let mut group = MlsGroup::load(provider.storage(), &GroupId::from_slice(&fixture.group_id))
        .expect("load native group in wasm")
        .expect("native group exists in wasm");
    let processed = group
        .process_message(
            &provider,
            MlsMessageIn::tls_deserialize_exact(fixture.first_message)
                .expect("deserialize native application message")
                .try_into_protocol_message()
                .expect("native protocol message"),
        )
        .expect("process native application message in wasm");
    let ProcessedMessageContent::ApplicationMessage(application) = processed.into_content() else {
        panic!("expected native application message");
    };
    assert_eq!(
        application.into_bytes(),
        b"native message processed by wasm"
    );

    let advanced_state = provider
        .export_state()
        .expect("serialize wasm-advanced state");
    let receiver = option_env!("RC_E2EE_STATE_RECEIVER").expect("state receiver URL");
    let request_init = RequestInit::new();
    request_init.set_method("POST");
    request_init.set_body(&STANDARD.encode(advanced_state).into());
    let request = Request::new_with_str_and_init(receiver, &request_init)
        .expect("create state receiver request");
    request
        .headers()
        .set("Content-Type", "text/plain")
        .expect("set state content type");
    let response = JsFuture::from(
        web_sys::window()
            .expect("browser window")
            .fetch_with_request(&request),
    )
    .await
    .expect("post wasm-advanced state");
    let response: web_sys::Response = response.into();
    assert_eq!(response.status(), 204);
}
