use std::{
    env, fs,
    io::{Read, Write},
    net::TcpListener,
    path::Path,
};

use base64::{engine::general_purpose::STANDARD, Engine};
use openmls::prelude::tls_codec::Deserialize;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_traits::OpenMlsProvider;
use redcode_e2ee_core::ProtocolProvider;

#[path = "../interop/fixture.rs"]
mod fixture_format;

use fixture_format::CrossRuntimeFixture;

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

struct FixtureDevice {
    provider: ProtocolProvider,
    credential: CredentialWithKey,
    signer: SignatureKeyPair,
}

impl FixtureDevice {
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

fn main() {
    let args = env::args().collect::<Vec<_>>();
    match args.as_slice() {
        [_, command, fixture_path] if command == "generate" => generate(Path::new(fixture_path)),
        [_, command, fixture_path, browser_output] if command == "verify" => {
            verify(Path::new(fixture_path), Path::new(browser_output))
        }
        [_, command, port_path, state_path] if command == "receive" => {
            receive(Path::new(port_path), Path::new(state_path))
        }
        _ => panic!(
            "usage: cross_runtime_fixture generate <fixture> | receive <port-file> <state-file> | verify <fixture> <state-file>"
        ),
    }
}

fn generate(path: &Path) {
    let alice = FixtureDevice::new("alice-native-device");
    let bob = FixtureDevice::new("bob-cross-runtime-device");
    let group_id = b"redcode-cross-runtime-room";
    let mut alice_group = MlsGroup::new_with_group_id(
        &alice.provider,
        &alice.signer,
        &MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .use_ratchet_tree_extension(true)
            .build(),
        GroupId::from_slice(group_id),
        alice.credential.clone(),
    )
    .expect("create fixture group");
    let (_, welcome, _) = alice_group
        .add_members(
            &alice.provider,
            &alice.signer,
            &[bob.key_package().key_package().clone()],
        )
        .expect("add fixture member");
    alice_group
        .merge_pending_commit(&alice.provider)
        .expect("merge fixture add commit");

    let welcome = match as_message_in(welcome).extract() {
        MlsMessageBodyIn::Welcome(welcome) => welcome,
        _ => panic!("expected welcome message"),
    };
    StagedWelcome::new_from_welcome(
        &bob.provider,
        &MlsGroupJoinConfig::builder()
            .use_ratchet_tree_extension(true)
            .build(),
        welcome,
        None,
    )
    .expect("stage fixture welcome")
    .into_group(&bob.provider)
    .expect("join fixture group");

    let first_message = alice_group
        .create_message(
            &alice.provider,
            &alice.signer,
            b"native message processed by wasm",
        )
        .expect("create first fixture message")
        .to_bytes()
        .expect("serialize first fixture message");
    let second_message = alice_group
        .create_message(
            &alice.provider,
            &alice.signer,
            b"native message after wasm state export",
        )
        .expect("create second fixture message")
        .to_bytes()
        .expect("serialize second fixture message");
    let fixture = CrossRuntimeFixture {
        group_id: group_id.to_vec(),
        provider_state: bob.provider.export_state().expect("export provider state"),
        first_message,
        second_message,
    };
    fs::write(path, fixture.encode()).expect("write cross-runtime fixture");
}

fn receive(port_path: &Path, state_path: &Path) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind state receiver");
    fs::write(
        port_path,
        listener
            .local_addr()
            .expect("read receiver address")
            .port()
            .to_string(),
    )
    .expect("write receiver port");

    let (mut stream, _) = listener.accept().expect("accept browser state");
    let mut request = Vec::new();
    let mut buffer = [0_u8; 4096];
    let header_end = loop {
        let read = stream.read(&mut buffer).expect("read browser request");
        assert!(read > 0, "browser closed state request");
        request.extend_from_slice(&buffer[..read]);
        if let Some(position) = request.windows(4).position(|bytes| bytes == b"\r\n\r\n") {
            break position + 4;
        }
    };
    let headers = std::str::from_utf8(&request[..header_end]).expect("valid request headers");
    let content_length = headers
        .lines()
        .find_map(|line| {
            line.split_once(':').and_then(|(name, value)| {
                name.eq_ignore_ascii_case("content-length")
                    .then(|| value.trim().parse::<usize>().expect("valid content length"))
            })
        })
        .expect("content-length header");
    while request.len() - header_end < content_length {
        let read = stream.read(&mut buffer).expect("read browser state body");
        assert!(read > 0, "browser closed state body");
        request.extend_from_slice(&buffer[..read]);
    }
    let encoded_state = &request[header_end..header_end + content_length];
    let state = STANDARD
        .decode(encoded_state)
        .expect("decode browser state body");
    fs::write(state_path, state).expect("write browser state");
    stream
        .write_all(
            b"HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
        )
        .expect("respond to browser state request");
}

fn verify(fixture_path: &Path, state_path: &Path) {
    let fixture =
        CrossRuntimeFixture::decode(&fs::read(fixture_path).expect("read cross-runtime fixture"))
            .expect("decode cross-runtime fixture");
    let state = fs::read(state_path).expect("read browser state");
    let provider = ProtocolProvider::import_state(&state).expect("import browser state");
    let mut group = MlsGroup::load(provider.storage(), &GroupId::from_slice(&fixture.group_id))
        .expect("load browser-exported group")
        .expect("browser-exported group exists");
    let processed = group
        .process_message(
            &provider,
            as_message_in_bytes(&fixture.second_message)
                .try_into_protocol_message()
                .expect("second protocol message"),
        )
        .expect("process second message after browser state export");
    let ProcessedMessageContent::ApplicationMessage(application) = processed.into_content() else {
        panic!("expected second application message");
    };
    assert_eq!(
        application.into_bytes(),
        b"native message after wasm state export"
    );
}

fn as_message_in(message: MlsMessageOut) -> MlsMessageIn {
    as_message_in_bytes(&message.to_bytes().expect("serialize MLS message"))
}

fn as_message_in_bytes(message: &[u8]) -> MlsMessageIn {
    MlsMessageIn::tls_deserialize_exact(message).expect("deserialize MLS message")
}
