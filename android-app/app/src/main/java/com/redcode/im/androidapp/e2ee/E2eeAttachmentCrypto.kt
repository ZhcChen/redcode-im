package com.redcode.im.androidapp.e2ee

import java.nio.ByteBuffer
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class E2eeEncryptedAttachment(val ciphertext: ByteArray, val nonce: ByteArray, val dek: ByteArray)

class E2eeAttachmentCrypto(private val random: SecureRandom = SecureRandom()) {
    fun attachmentAad(roomId: String, partKey: String, partPosition: Int, objectKey: String): ByteArray {
        require(partPosition >= 0) { "E2EE 附件 part_position 无效" }
        require(objectKey.isNotBlank()) { "E2EE 附件 object key 不能为空" }
        val domain = "redcode-im/e2ee/attachment/v1\u0000".toByteArray()
        val objectBytes = objectKey.toByteArray()
        return ByteBuffer.allocate(domain.size + 16 + 16 + 4 + objectBytes.size).apply {
            put(domain); putUuid(roomId); putUuid(partKey); putInt(partPosition); put(objectBytes)
        }.array()
    }

    fun encrypt(plaintext: ByteArray, aad: ByteArray): E2eeEncryptedAttachment {
        val dek = ByteArray(32).also(random::nextBytes)
        val nonce = ByteArray(12).also(random::nextBytes)
        return E2eeEncryptedAttachment(crypt(Cipher.ENCRYPT_MODE, plaintext, aad, nonce, dek), nonce, dek)
    }

    fun decrypt(ciphertext: ByteArray, aad: ByteArray, nonce: ByteArray, dek: ByteArray): ByteArray {
        require(nonce.size == 12 && dek.size == 32) { "E2EE 附件密钥参数无效" }
        return try { crypt(Cipher.DECRYPT_MODE, ciphertext, aad, nonce, dek) }
        catch (error: AEADBadTagException) { throw E2eeDirectMessageException("E2EE 附件密文校验失败", error) }
    }

    private fun crypt(mode: Int, input: ByteArray, aad: ByteArray, nonce: ByteArray, dek: ByteArray): ByteArray =
        Cipher.getInstance("AES/GCM/NoPadding").run {
            init(mode, SecretKeySpec(dek, "AES"), GCMParameterSpec(128, nonce)); updateAAD(aad); doFinal(input)
        }
}

object E2eePeripheralPolicy {
    const val PUSH_PLACEHOLDER = "你收到一条加密消息"
    const val DECRYPTION_FAILED = "[无法解密的消息]"
    fun canIndexLocally(decrypted: Boolean, text: String?) = decrypted && !text.isNullOrBlank()
    fun canUseServerSearch() = false
    fun canForwardCiphertext() = false
    fun quotePreview(decryptedText: String?) = decryptedText?.takeIf { it.isNotBlank() } ?: "[加密消息]"
}

private fun ByteBuffer.putUuid(value: String) {
    val uuid = try { UUID.fromString(value) } catch (error: IllegalArgumentException) { throw IllegalArgumentException("E2EE 附件 UUID 格式无效", error) }
    putLong(uuid.mostSignificantBits); putLong(uuid.leastSignificantBits)
}
