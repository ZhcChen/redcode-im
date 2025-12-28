use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use machine_uid;
use sha2::{Digest, Sha256};
use std::path::PathBuf;

pub mod secret;
pub use secret::SecretCrypto;

/// 应用固定盐值（用于生成加密密钥）
const APP_SALT: &[u8] = b"redcode-im-v1-salt-2024";

/// Token 加密/解密器
pub struct TokenCrypto {
    cipher: Aes256Gcm,
}

impl TokenCrypto {
    /// 创建加密器
    pub fn new(app_data_dir: &PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        let key = Self::generate_device_key(app_data_dir)?;
        let cipher = Aes256Gcm::new(&key.into());
        Ok(Self { cipher })
    }

    /// 生成设备唯一密钥
    ///
    /// 密钥组成：
    /// - 机器 ID（硬件标识）
    /// - 应用盐值（固定）
    /// - 用户数据目录路径
    ///
    /// 使用 SHA256 生成 32 字节密钥
    fn generate_device_key(app_data_dir: &PathBuf) -> Result<[u8; 32], Box<dyn std::error::Error>> {
        // 获取机器 ID
        let machine_id =
            machine_uid::get().map_err(|e| format!("Failed to get machine ID: {}", e))?;

        // 获取数据目录路径
        let dir_path = app_data_dir
            .to_str()
            .ok_or("Invalid app data directory path")?;

        // 组合所有熵源
        let mut hasher = Sha256::new();
        hasher.update(machine_id.as_bytes());
        hasher.update(APP_SALT);
        hasher.update(dir_path.as_bytes());

        // 生成 32 字节密钥
        let result = hasher.finalize();
        let mut key = [0u8; 32];
        key.copy_from_slice(&result);

        Ok(key)
    }

    /// 加密 token
    ///
    /// 使用 AES-256-GCM 加密
    /// 返回: nonce(12字节) + ciphertext
    pub fn encrypt(&self, token: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        // 生成随机 nonce（12 字节）
        let nonce_bytes = Self::generate_nonce();
        let nonce = Nonce::from_slice(&nonce_bytes);

        // 加密
        let ciphertext = self
            .cipher
            .encrypt(nonce, token.as_bytes())
            .map_err(|e| format!("Encryption failed: {}", e))?;

        // 组合: nonce + ciphertext
        let mut result = Vec::with_capacity(12 + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);

        Ok(result)
    }

    /// 解密 token
    ///
    /// 输入: nonce(12字节) + ciphertext
    /// 返回: 明文 token
    pub fn decrypt(&self, encrypted: &[u8]) -> Result<String, Box<dyn std::error::Error>> {
        if encrypted.len() < 12 {
            return Err("Invalid encrypted data: too short".into());
        }

        // 分离 nonce 和 ciphertext
        let (nonce_bytes, ciphertext) = encrypted.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);

        // 解密
        let plaintext = self
            .cipher
            .decrypt(nonce, ciphertext)
            .map_err(|e| format!("Decryption failed: {}", e))?;

        // 转换为字符串
        let token = String::from_utf8(plaintext).map_err(|e| format!("Invalid UTF-8: {}", e))?;

        Ok(token)
    }

    /// 生成随机 nonce（12 字节）
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
    use std::path::PathBuf;

    #[test]
    fn test_encrypt_decrypt() {
        let app_data_dir = PathBuf::from("/tmp/test_app");
        let crypto = TokenCrypto::new(&app_data_dir).unwrap();

        let original = "test_token_12345";
        let encrypted = crypto.encrypt(original).unwrap();
        let decrypted = crypto.decrypt(&encrypted).unwrap();

        assert_eq!(original, decrypted);
    }

    #[test]
    fn test_different_tokens() {
        let app_data_dir = PathBuf::from("/tmp/test_app");
        let crypto = TokenCrypto::new(&app_data_dir).unwrap();

        let token1 = "token1";
        let token2 = "token2";

        let encrypted1 = crypto.encrypt(token1).unwrap();
        let encrypted2 = crypto.encrypt(token2).unwrap();

        // 加密后应该不同
        assert_ne!(encrypted1, encrypted2);

        // 解密后应该正确
        assert_eq!(crypto.decrypt(&encrypted1).unwrap(), token1);
        assert_eq!(crypto.decrypt(&encrypted2).unwrap(), token2);
    }
}
