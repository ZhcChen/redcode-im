package com.redcode.im.androidapp.e2ee

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class E2eeSecureStateStoreTest {
    private lateinit var cipher: InMemoryE2eeStateCipher
    private lateinit var blobs: InMemoryE2eeStateBlobStore
    private lateinit var store: E2eeSecureStateStore

    @Before
    fun setUp() {
        cipher = InMemoryE2eeStateCipher()
        blobs = InMemoryE2eeStateBlobStore()
        store = E2eeSecureStateStore(cipher, blobs)
    }

    @Test
    fun encryptsAndRestoresAccountScopedProtocolState() {
        val state = E2eeCommandClient().newProtocolState()

        store.write("account-a", state)

        assertArrayEquals(state, store.read("account-a"))
        assertNull(store.read("account-b"))
    }

    @Test
    fun neverPersistsStateRejectedBySharedCore() {
        assertThrows(E2eeStateCorruptedException::class.java) {
            store.write("account-a", byteArrayOf(1, 2, 3))
        }
        assertNull(store.read("account-a"))
    }

    @Test
    fun failsClosedWhenCiphertextIsTampered() {
        store.write("account-a", E2eeCommandClient().newProtocolState())
        val blob = blobs.load("account-a")!!
        val tampered = blob.copy(ciphertext = blob.ciphertext.copyOf().also { it[0] = it[0].toInt().xor(0xFF).toByte() })
        blobs.save("account-a", tampered)

        assertThrows(E2eeStateCorruptedException::class.java) {
            store.read("account-a")
        }
    }

    @Test
    fun failsClosedWhenWrappingKeyIsMissing() {
        store.write("account-a", E2eeCommandClient().newProtocolState())

        cipher.deleteKey("account-a")

        assertThrows(E2eeStateCorruptedException::class.java) {
            store.read("account-a")
        }
    }

    @Test
    fun failsClosedWhenEnvelopeVersionIsUnsupported() {
        store.write("account-a", E2eeCommandClient().newProtocolState())
        val blob = blobs.load("account-a")!!
        blobs.save("account-a", blob.copy(version = blob.version + 1))

        assertThrows(E2eeStateCorruptedException::class.java) {
            store.read("account-a")
        }
    }

    @Test
    fun accountCleanupRemovesCiphertextAndWrappingKey() {
        store.write("account-a", E2eeCommandClient().newProtocolState())

        store.delete("account-a")

        assertNull(store.read("account-a"))
        assertNull(blobs.load("account-a"))
        assertThrows(E2eeStateCorruptedException::class.java) {
            cipher.decrypt("account-a", E2eeEncryptedStateBlob(1, ByteArray(12), ByteArray(1)))
        }
    }

    @Test
    fun nonceIsRandomPerWrite() {
        val state = E2eeCommandClient().newProtocolState()
        store.write("account-a", state)
        val first = blobs.load("account-a")!!.nonce
        store.write("account-a", state)
        val second = blobs.load("account-a")!!.nonce

        assertFalse(first.contentEquals(second))
        assertTrue(blobs.load("account-a")!!.nonce.size == 12)
    }
}
