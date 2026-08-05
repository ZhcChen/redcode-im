package com.redcode.im.androidapp.e2ee

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class E2eeCommandClientTest {
    private lateinit var client: E2eeCommandClient

    @Before
    fun setUp() {
        client = E2eeCommandClient(E2eeCoreNative.load())
    }

    @Test
    fun protocolVersionMatchesSharedCore() {
        assertEquals(1, client.protocolVersion)
    }

    @Test
    fun newProtocolStateIsValid() {
        val state = client.newProtocolState()
        assertTrue(client.validateProtocolState(state))
    }

    @Test
    fun tamperedProtocolStateIsInvalid() {
        val state = client.newProtocolState()
        state[state.size - 1] = (state[state.size - 1].toInt() xor 0xFF).toByte()
        assertFalse(client.validateProtocolState(state))
    }

    @Test
    fun twoDeviceRoundTripMatchesCommandContract() {
        // 与 e2ee-core/tests/command_api.rs / iOS 测试对齐的双设备流程。
        val alice = client.initialize("alice-device-android")
        val bob = client.initialize("bob-device-android")
        val aliceState = alice.field(0)
        val bobState = bob.field(0)
        val bobKeyPackage = bob.field(1)
        assertTrue(client.validateProtocolState(aliceState))
        assertTrue(client.validateProtocolState(bobState))

        val created = client.createGroup(aliceState, "room-android-unit")
        val added = client.execute(
            E2eeCommandOperation.AddMember,
            listOf(created.field(0), "room-android-unit".toByteArray(), bobKeyPackage),
        )
        val joined = client.execute(
            E2eeCommandOperation.JoinGroup,
            listOf(bobState, added.field(2)),
        )

        val plaintext = "native e2ee round trip".toByteArray()
        val encrypted = client.encrypt(added.field(0), "room-android-unit", plaintext)
        val ciphertext = encrypted.field(1)
        assertNotEquals(ciphertext.toList(), plaintext.toList())

        val decrypted = client.decrypt(joined.field(0), "room-android-unit", ciphertext)
        assertArrayEquals(plaintext, decrypted.field(1))
        assertEquals(1L, decrypted.epoch(2))
    }

    @Test
    fun unknownOperationFailsClosed() {
        val badRequest = byteArrayOf(
            'R'.code.toByte(), 'C'.code.toByte(), 'C'.code.toByte(), 'Q'.code.toByte(),
            0, 1, 99, 0,
        )
        val response = client.executeRaw(badRequest)
        assertEquals("RCCR", response.copyOfRange(0, 4).toString(Charsets.UTF_8))
        assertEquals(1, response[6].toInt())
    }
}
