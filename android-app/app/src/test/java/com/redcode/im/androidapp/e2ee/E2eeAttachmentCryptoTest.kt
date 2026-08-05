package com.redcode.im.androidapp.e2ee

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class E2eeAttachmentCryptoTest {
    private val crypto = E2eeAttachmentCrypto()
    private val aad = crypto.attachmentAad(
        "11111111-2222-4333-8444-555555555555",
        "00000000-0000-4000-8000-000000000001",
        0,
        "messages/r1/files/secret.bin",
    )

    @Test fun roundTripUsesWebCryptoCompatibleCiphertextAndTag() {
        val encrypted = crypto.encrypt("top secret attachment".toByteArray(), aad)
        assertArrayEquals("top secret attachment".toByteArray(), crypto.decrypt(encrypted.ciphertext, aad, encrypted.nonce, encrypted.dek))
        assertTrue(encrypted.ciphertext.size == "top secret attachment".toByteArray().size + 16)
        assertTrue(encrypted.nonce.size == 12 && encrypted.dek.size == 32)
    }

    @Test fun tamperedAadFailsClosed() {
        val encrypted = crypto.encrypt("secret".toByteArray(), aad)
        val tampered = crypto.attachmentAad("11111111-2222-4333-8444-555555555555", "00000000-0000-4000-8000-000000000001", 1, "messages/r1/files/secret.bin")
        assertTrue(runCatching { crypto.decrypt(encrypted.ciphertext, tampered, encrypted.nonce, encrypted.dek) }.exceptionOrNull() is E2eeDirectMessageException)
    }

    @Test fun retryGeneratesFreshNonceAndDek() {
        val first = crypto.encrypt(byteArrayOf(1), aad); val second = crypto.encrypt(byteArrayOf(1), aad)
        assertFalse(first.nonce.contentEquals(second.nonce)); assertFalse(first.dek.contentEquals(second.dek))
    }

    @Test fun aadUsesBigEndianPositionAndPeripheralPolicyFailsClosed() {
        val positioned = crypto.attachmentAad("11111111-2222-4333-8444-555555555555", "00000000-0000-4000-8000-000000000001", 0x01020304, "key")
        val domainSize = "redcode-im/e2ee/attachment/v1\u0000".toByteArray().size
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), positioned.copyOfRange(domainSize + 32, domainSize + 36))
        assertFalse(E2eePeripheralPolicy.canUseServerSearch()); assertFalse(E2eePeripheralPolicy.canForwardCiphertext())
        assertTrue(E2eePeripheralPolicy.canIndexLocally(true, "decrypted")); assertNotEquals("", E2eePeripheralPolicy.PUSH_PLACEHOLDER)
    }
}
