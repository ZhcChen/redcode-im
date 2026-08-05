package com.redcode.im.androidapp.e2ee

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Android Keystore 实现的账号级包装密钥：AES-256-GCM 密钥不可导出，
 * 加解密由 Keystore 完成，密文始终带随机 nonce 与账号绑定的 AAD。
 */
class KeystoreE2eeStateCipher : E2eeStateCipher {
    private val keyStore =
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    override fun encrypt(accountId: String, plaintext: ByteArray): E2eeEncryptedStateBlob {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, keyFor(accountId))
        cipher.updateAAD(e2eeStateAssociatedData(accountId))
        return E2eeEncryptedStateBlob(
            version = STATE_VERSION,
            nonce = cipher.iv,
            ciphertext = cipher.doFinal(plaintext),
        )
    }

    override fun decrypt(accountId: String, blob: E2eeEncryptedStateBlob): ByteArray {
        if (blob.version != STATE_VERSION) {
            throw E2eeStateCorruptedException("E2EE 状态版本不匹配")
        }
        val key =
            runCatching {
                keyStore.getKey(keyAlias(accountId), null) as? SecretKey
            }.getOrNull()
                ?: throw E2eeStateCorruptedException("E2EE 包装密钥缺失")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, blob.nonce))
        cipher.updateAAD(e2eeStateAssociatedData(accountId))
        return try {
            cipher.doFinal(blob.ciphertext)
        } catch (e: GeneralSecurityException) {
            throw E2eeStateCorruptedException()
        }
    }

    override fun deleteKey(accountId: String) {
        keyStore.deleteEntry(keyAlias(accountId))
    }

    private fun keyFor(accountId: String): SecretKey {
        val existing =
            runCatching {
                keyStore.getKey(keyAlias(accountId), null) as? SecretKey
            }.getOrNull()
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec =
            KeyGenParameterSpec
                .Builder(keyAlias(accountId), KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun keyAlias(accountId: String): String =
        "redcode_e2ee_state_${accountId.trim()}"

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val STATE_VERSION = 1
    }
}
