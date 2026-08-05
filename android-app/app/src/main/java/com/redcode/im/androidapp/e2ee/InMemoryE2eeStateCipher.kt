package com.redcode.im.androidapp.e2ee

import java.security.GeneralSecurityException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * JVM 测试用 AES-GCM 包装密钥实现：行为与 Keystore 版本一致（随机 nonce、
 * AAD 绑定账号、密钥缺失/篡改/版本不匹配 fail closed），仅密钥存在内存。
 */
class InMemoryE2eeStateCipher : E2eeStateCipher {
    private val keys = mutableMapOf<String, SecretKey>()

    override fun encrypt(
        accountId: String,
        plaintext: ByteArray,
        aad: ByteArray,
    ): E2eeEncryptedStateBlob {
        val key = keys.getOrPut(accountId) { generateKey() }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(aad)
        return E2eeEncryptedStateBlob(
            version = STATE_VERSION,
            nonce = cipher.iv,
            ciphertext = cipher.doFinal(plaintext),
        )
    }

    override fun decrypt(
        accountId: String,
        blob: E2eeEncryptedStateBlob,
        aad: ByteArray,
    ): ByteArray {
        if (blob.version != STATE_VERSION) {
            throw E2eeStateCorruptedException("E2EE 状态版本不匹配")
        }
        val key =
            keys[accountId]
                ?: throw E2eeStateCorruptedException("E2EE 包装密钥缺失")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, blob.nonce))
        cipher.updateAAD(aad)
        return try {
            cipher.doFinal(blob.ciphertext)
        } catch (e: GeneralSecurityException) {
            throw E2eeStateCorruptedException()
        }
    }

    override fun deleteKey(accountId: String) {
        keys.remove(accountId)
    }

    private fun generateKey(): SecretKey =
        KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    companion object {
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val STATE_VERSION = 1
    }
}
