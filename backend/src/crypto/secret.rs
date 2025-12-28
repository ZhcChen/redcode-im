use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use base64::Engine;
use sha2::{Digest, Sha256};
use std::env;

/// 用于服务端加密 DB 中敏感配置的固定盐值
const SECRET_SALT: &[u8] = b"redcode-im-secret-config-v1";

pub struct SecretCrypto {
    cipher: Aes256Gcm,
}

impl SecretCrypto {
    pub fn new() -> Result<Self, String> {
        let key = Self::derive_key()?;
        Ok(Self {
            cipher: Aes256Gcm::new(&key.into()),
        })
    }

    pub fn encrypt_to_base64(&self, plaintext: &str) -> Result<String, String> {
        let nonce_bytes = Self::generate_nonce();
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = self
            .cipher
            .encrypt(nonce, plaintext.as_bytes())
            .map_err(|e| format!("encrypt failed: {}", e))?;

        let mut out = Vec::with_capacity(12 + ciphertext.len());
        out.extend_from_slice(&nonce_bytes);
        out.extend_from_slice(&ciphertext);

        Ok(base64::engine::general_purpose::STANDARD.encode(out))
    }

    pub fn decrypt_from_base64(&self, ciphertext_base64: &str) -> Result<String, String> {
        let raw = base64::engine::general_purpose::STANDARD
            .decode(ciphertext_base64.as_bytes())
            .map_err(|e| format!("base64 decode failed: {}", e))?;

        if raw.len() < 12 {
            return Err("invalid ciphertext: too short".to_string());
        }

        let (nonce_bytes, ciphertext) = raw.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);

        let plaintext = self
            .cipher
            .decrypt(nonce, ciphertext)
            .map_err(|e| format!("decrypt failed: {}", e))?;

        String::from_utf8(plaintext).map_err(|e| format!("invalid utf8: {}", e))
    }

    pub fn sha256_hex(plaintext: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(plaintext.as_bytes());
        let out = hasher.finalize();
        hex::encode(out)
    }

    fn derive_key() -> Result<[u8; 32], String> {
        // 优先使用独立的加密密钥；缺省则回退到 JWT_SECRET（开发环境兼容）。
        let raw = env::var("DATA_ENCRYPTION_KEY")
            .ok()
            .filter(|v| !v.trim().is_empty())
            .or_else(|| {
                env::var("JWT_SECRET")
                    .ok()
                    .filter(|v| !v.trim().is_empty())
            })
            .ok_or_else(|| "DATA_ENCRYPTION_KEY / JWT_SECRET 均未设置".to_string())?;

        let mut hasher = Sha256::new();
        hasher.update(raw.as_bytes());
        hasher.update(SECRET_SALT);
        let out = hasher.finalize();

        let mut key = [0u8; 32];
        key.copy_from_slice(&out);
        Ok(key)
    }

    fn generate_nonce() -> [u8; 12] {
        use rand::Rng;
        let mut nonce = [0u8; 12];
        rand::thread_rng().fill(&mut nonce);
        nonce
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encrypt_decrypt_roundtrip() {
        std::env::set_var("DATA_ENCRYPTION_KEY", "test-key");
        let crypto = SecretCrypto::new().unwrap();

        let plaintext = r#"{"foo":"bar","n":123}"#;
        let encoded = crypto.encrypt_to_base64(plaintext).unwrap();
        let decoded = crypto.decrypt_from_base64(&encoded).unwrap();

        assert_eq!(decoded, plaintext);
    }
}

