use openmls::prelude::tls_codec::{Deserialize, Serialize};
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_traits::signatures::Signer;
use openmls_traits::OpenMlsProvider;
use sha2::{Digest, Sha256};
use thiserror::Error;

use crate::{Envelope, EnvelopeKind, ProtocolProvider, StateError};

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
const IDENTITY_KEY: &[u8] = b"redcode/session/identity/v1";
const SIGNATURE_PUBLIC_KEY: &[u8] = b"redcode/session/signature-public/v1";
const ROOT_PUBLIC_KEY: &[u8] = b"redcode/session/root-public/v1";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MlsBootstrap {
    pub key_package: Vec<u8>,
    pub state: Vec<u8>,
    pub public_material: MlsPublicMaterial,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MlsPublicMaterial {
    pub root_public_key: Vec<u8>,
    pub root_fingerprint: Vec<u8>,
    pub credential: Vec<u8>,
    pub credential_fingerprint: Vec<u8>,
    pub approval_public_key: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MlsApplication {
    pub plaintext: Vec<u8>,
    pub epoch: u64,
    pub state: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MlsMemberAdd {
    pub commit: Vec<u8>,
    pub welcome: Vec<u8>,
    pub epoch: u64,
    pub state: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MlsMemberRemove {
    pub commit: Vec<u8>,
    pub epoch: u64,
    pub state: Vec<u8>,
}

#[derive(Debug)]
pub struct MlsSession {
    provider: ProtocolProvider,
}

impl MlsSession {
    pub fn initialize(identity: &[u8]) -> Result<MlsBootstrap, MlsSessionError> {
        Self::initialize_with_root(identity, None)
    }

    pub fn initialize_with_root(
        identity: &[u8],
        root_public_key: Option<&[u8]>,
    ) -> Result<MlsBootstrap, MlsSessionError> {
        if identity.is_empty() || identity.len() > u16::MAX as usize {
            return Err(MlsSessionError::InvalidIdentity);
        }
        let provider = ProtocolProvider::default();
        let signer = SignatureKeyPair::new(CIPHERSUITE.signature_algorithm())
            .map_err(operation("create signature key"))?;
        signer
            .store(provider.storage())
            .map_err(operation("store signature key"))?;
        let root_public_key = root_public_key
            .map(ToOwned::to_owned)
            .unwrap_or_else(|| signer.to_public_vec());
        if root_public_key.len() != 32 {
            return Err(MlsSessionError::InvalidRootPublicKey);
        }
        {
            let mut values = provider
                .storage
                .values
                .write()
                .map_err(|_| MlsSessionError::StorageLockPoisoned)?;
            values.insert(IDENTITY_KEY.to_vec(), identity.to_vec());
            values.insert(SIGNATURE_PUBLIC_KEY.to_vec(), signer.to_public_vec());
            values.insert(ROOT_PUBLIC_KEY.to_vec(), root_public_key);
        }
        let session = Self { provider };
        let key_package = session.generate_key_package()?;
        Ok(MlsBootstrap {
            key_package,
            state: session.export_state()?,
            public_material: session.public_material()?,
        })
    }

    pub fn import(state: &[u8]) -> Result<Self, MlsSessionError> {
        let session = Self {
            provider: ProtocolProvider::import_state(state)?,
        };
        session.identity_and_signer()?;
        Ok(session)
    }

    pub fn export_state(&self) -> Result<Vec<u8>, MlsSessionError> {
        Ok(self.provider.export_state()?)
    }

    pub fn generate_key_package(&self) -> Result<Vec<u8>, MlsSessionError> {
        let (credential, signer) = self.identity_and_signer()?;
        let bundle = KeyPackage::builder()
            .build(CIPHERSUITE, &self.provider, &signer, credential)
            .map_err(operation("create key package"))?;
        bundle
            .key_package()
            .tls_serialize_detached()
            .map_err(operation("serialize key package"))
    }

    pub fn public_material(&self) -> Result<MlsPublicMaterial, MlsSessionError> {
        let values = self
            .provider
            .storage
            .values
            .read()
            .map_err(|_| MlsSessionError::StorageLockPoisoned)?;
        let identity = values
            .get(IDENTITY_KEY)
            .ok_or(MlsSessionError::NotInitialized)?;
        let signature_public = values
            .get(SIGNATURE_PUBLIC_KEY)
            .ok_or(MlsSessionError::NotInitialized)?;
        let root_public_key = values
            .get(ROOT_PUBLIC_KEY)
            .ok_or(MlsSessionError::NotInitialized)?
            .clone();
        let mut credential = Vec::with_capacity(identity.len() + 1 + signature_public.len());
        credential.extend_from_slice(identity);
        credential.push(0);
        credential.extend_from_slice(signature_public);
        Ok(MlsPublicMaterial {
            root_fingerprint: Sha256::digest(&root_public_key).to_vec(),
            credential_fingerprint: Sha256::digest(&credential).to_vec(),
            approval_public_key: signature_public.clone(),
            root_public_key,
            credential,
        })
    }

    pub fn create_group(&mut self, group_id: &[u8]) -> Result<Vec<u8>, MlsSessionError> {
        validate_group_id(group_id)?;
        if MlsGroup::load(self.provider.storage(), &GroupId::from_slice(group_id))
            .map_err(operation("load group"))?
            .is_some()
        {
            return Err(MlsSessionError::GroupAlreadyExists);
        }
        let (credential, signer) = self.identity_and_signer()?;
        MlsGroup::new_with_group_id(
            &self.provider,
            &signer,
            &MlsGroupCreateConfig::builder()
                .ciphersuite(CIPHERSUITE)
                .use_ratchet_tree_extension(true)
                .build(),
            GroupId::from_slice(group_id),
            credential,
        )
        .map_err(operation("create group"))?;
        self.export_state()
    }

    pub fn add_member(
        &mut self,
        group_id: &[u8],
        key_package: &[u8],
    ) -> Result<MlsMemberAdd, MlsSessionError> {
        let (_, signer) = self.identity_and_signer()?;
        let key_package = KeyPackageIn::tls_deserialize_exact(key_package)
            .map_err(operation("decode key package"))?
            .validate(self.provider.crypto(), ProtocolVersion::Mls10)
            .map_err(operation("validate key package"))?;
        let mut group = self.load_group(group_id)?;
        let (commit, welcome, _) = group
            .add_members(&self.provider, &signer, &[key_package])
            .map_err(operation("add member"))?;
        group
            .merge_pending_commit(&self.provider)
            .map_err(operation("merge add commit"))?;
        let epoch = group.epoch().as_u64();
        let commit = encode_message(EnvelopeKind::Commit, commit)?;
        let welcome = encode_message(EnvelopeKind::Welcome, welcome)?;
        Ok(MlsMemberAdd {
            commit,
            welcome,
            epoch,
            state: self.export_state()?,
        })
    }

    /// 从群组中移除指定设备 identity 对应的成员，并生成本地已合并的 Commit。
    ///
    /// 被移除成员不需要 Welcome；房间其余设备通过 process_commit 收敛到新 epoch。
    pub fn remove_member(
        &mut self,
        group_id: &[u8],
        identity: &[u8],
    ) -> Result<MlsMemberRemove, MlsSessionError> {
        if identity.is_empty() {
            return Err(MlsSessionError::InvalidIdentity);
        }
        let (_, signer) = self.identity_and_signer()?;
        let mut group = self.load_group(group_id)?;
        let credential: Credential = BasicCredential::new(identity.to_vec()).into();
        let leaf_index = group
            .member_leaf_index(&credential)
            .ok_or(MlsSessionError::MemberNotFound)?;
        let (commit, _, _) = group
            .remove_members(&self.provider, &signer, &[leaf_index])
            .map_err(operation("remove member"))?;
        group
            .merge_pending_commit(&self.provider)
            .map_err(operation("merge remove commit"))?;
        let epoch = group.epoch().as_u64();
        let commit = encode_message(EnvelopeKind::Commit, commit)?;
        Ok(MlsMemberRemove {
            commit,
            epoch,
            state: self.export_state()?,
        })
    }

    /// 返回当前群组全部 leaf 的 identity，供客户端与服务端成员集合做差集收敛。
    pub fn list_members(&self, group_id: &[u8]) -> Result<Vec<Vec<u8>>, MlsSessionError> {
        let group = self.load_group(group_id)?;
        let mut members = group
            .members()
            .map(|member| {
                let credential = &member.credential;
                if credential.credential_type() != CredentialType::Basic {
                    return Err(MlsSessionError::UnsupportedCredential);
                }
                Ok(credential.serialized_content().to_vec())
            })
            .collect::<Result<Vec<_>, _>>()?;
        members.sort();
        Ok(members)
    }

    /// 使用设备签名密钥对批准载荷签名，供可信设备批准同账号新设备。
    pub fn sign_device_approval(&self, payload: &[u8]) -> Result<Vec<u8>, MlsSessionError> {
        if payload.is_empty() {
            return Err(MlsSessionError::EmptySignaturePayload);
        }
        let (_, signer) = self.identity_and_signer()?;
        signer
            .sign(payload)
            .map_err(|error| MlsSessionError::Operation(format!("sign device approval: {error:?}")))
    }

    pub fn join_group(&mut self, welcome: &[u8]) -> Result<(Vec<u8>, u64), MlsSessionError> {
        let envelope = require_envelope(welcome, EnvelopeKind::Welcome)?;
        let message = MlsMessageIn::tls_deserialize_exact(envelope.payload())
            .map_err(operation("decode welcome"))?;
        let MlsMessageBodyIn::Welcome(welcome) = message.extract() else {
            return Err(MlsSessionError::UnexpectedMessage);
        };
        let group = StagedWelcome::new_from_welcome(
            &self.provider,
            &MlsGroupJoinConfig::builder()
                .use_ratchet_tree_extension(true)
                .build(),
            welcome,
            None,
        )
        .map_err(operation("stage welcome"))?
        .into_group(&self.provider)
        .map_err(operation("join group"))?;
        let epoch = group.epoch().as_u64();
        Ok((self.export_state()?, epoch))
    }

    pub fn process_commit(
        &mut self,
        group_id: &[u8],
        commit: &[u8],
    ) -> Result<(Vec<u8>, u64), MlsSessionError> {
        let envelope = require_envelope(commit, EnvelopeKind::Commit)?;
        let message = MlsMessageIn::tls_deserialize_exact(envelope.payload())
            .map_err(operation("decode commit"))?
            .try_into_protocol_message()
            .map_err(operation("convert commit"))?;
        let mut group = self.load_group(group_id)?;
        let processed = group
            .process_message(&self.provider, message)
            .map_err(operation("process commit"))?;
        let ProcessedMessageContent::StagedCommitMessage(staged) = processed.into_content() else {
            return Err(MlsSessionError::UnexpectedMessage);
        };
        group
            .merge_staged_commit(&self.provider, *staged)
            .map_err(operation("merge commit"))?;
        let epoch = group.epoch().as_u64();
        Ok((self.export_state()?, epoch))
    }

    pub fn encrypt(
        &mut self,
        group_id: &[u8],
        plaintext: &[u8],
    ) -> Result<(Vec<u8>, u64, Vec<u8>), MlsSessionError> {
        if plaintext.is_empty() {
            return Err(MlsSessionError::EmptyPlaintext);
        }
        let (_, signer) = self.identity_and_signer()?;
        let mut group = self.load_group(group_id)?;
        let epoch = group.epoch().as_u64();
        let message = group
            .create_message(&self.provider, &signer, plaintext)
            .map_err(operation("encrypt application message"))?;
        Ok((
            encode_message(EnvelopeKind::Application, message)?,
            epoch,
            self.export_state()?,
        ))
    }

    pub fn decrypt(
        &mut self,
        group_id: &[u8],
        application: &[u8],
    ) -> Result<MlsApplication, MlsSessionError> {
        let envelope = require_envelope(application, EnvelopeKind::Application)?;
        let message = MlsMessageIn::tls_deserialize_exact(envelope.payload())
            .map_err(operation("decode application message"))?
            .try_into_protocol_message()
            .map_err(operation("convert application message"))?;
        let epoch = message.epoch().as_u64();
        let mut group = self.load_group(group_id)?;
        let processed = group
            .process_message(&self.provider, message)
            .map_err(operation("decrypt application message"))?;
        let ProcessedMessageContent::ApplicationMessage(application) = processed.into_content()
        else {
            return Err(MlsSessionError::UnexpectedMessage);
        };
        Ok(MlsApplication {
            plaintext: application.into_bytes(),
            epoch,
            state: self.export_state()?,
        })
    }

    fn identity_and_signer(
        &self,
    ) -> Result<(CredentialWithKey, SignatureKeyPair), MlsSessionError> {
        let values = self
            .provider
            .storage
            .values
            .read()
            .map_err(|_| MlsSessionError::StorageLockPoisoned)?;
        let identity = values
            .get(IDENTITY_KEY)
            .cloned()
            .ok_or(MlsSessionError::NotInitialized)?;
        let public = values
            .get(SIGNATURE_PUBLIC_KEY)
            .cloned()
            .ok_or(MlsSessionError::NotInitialized)?;
        drop(values);
        let signer = SignatureKeyPair::read(
            self.provider.storage(),
            &public,
            CIPHERSUITE.signature_algorithm(),
        )
        .ok_or(MlsSessionError::NotInitialized)?;
        Ok((
            CredentialWithKey {
                credential: BasicCredential::new(identity).into(),
                signature_key: public.into(),
            },
            signer,
        ))
    }

    fn load_group(&self, group_id: &[u8]) -> Result<MlsGroup, MlsSessionError> {
        validate_group_id(group_id)?;
        MlsGroup::load(self.provider.storage(), &GroupId::from_slice(group_id))
            .map_err(operation("load group"))?
            .ok_or(MlsSessionError::GroupNotFound)
    }
}

fn encode_message(kind: EnvelopeKind, message: MlsMessageOut) -> Result<Vec<u8>, MlsSessionError> {
    let payload = message
        .to_bytes()
        .map_err(operation("serialize MLS message"))?;
    Ok(Envelope::try_new(kind, payload)?.encode())
}

fn require_envelope(encoded: &[u8], kind: EnvelopeKind) -> Result<Envelope, MlsSessionError> {
    let envelope = Envelope::decode(encoded)?;
    if envelope.kind() != kind {
        return Err(MlsSessionError::UnexpectedMessage);
    }
    Ok(envelope)
}

fn validate_group_id(group_id: &[u8]) -> Result<(), MlsSessionError> {
    if group_id.is_empty() || group_id.len() > 1024 {
        return Err(MlsSessionError::InvalidGroupId);
    }
    Ok(())
}

fn operation<E: std::fmt::Display>(context: &'static str) -> impl FnOnce(E) -> MlsSessionError {
    move |error| MlsSessionError::Operation(format!("{context}: {error}"))
}

#[derive(Debug, Error)]
pub enum MlsSessionError {
    #[error("invalid device identity")]
    InvalidIdentity,
    #[error("invalid group id")]
    InvalidGroupId,
    #[error("invalid account root public key")]
    InvalidRootPublicKey,
    #[error("empty application plaintext")]
    EmptyPlaintext,
    #[error("MLS session is not initialized")]
    NotInitialized,
    #[error("MLS group already exists")]
    GroupAlreadyExists,
    #[error("MLS group does not exist")]
    GroupNotFound,
    #[error("MLS group member not found")]
    MemberNotFound,
    #[error("unsupported MLS credential type")]
    UnsupportedCredential,
    #[error("empty signature payload")]
    EmptySignaturePayload,
    #[error("unexpected MLS message kind")]
    UnexpectedMessage,
    #[error("MLS session storage lock is poisoned")]
    StorageLockPoisoned,
    #[error("{0}")]
    State(#[from] StateError),
    #[error("{0}")]
    Envelope(#[from] crate::EnvelopeError),
    #[error("MLS operation failed: {0}")]
    Operation(String),
}
