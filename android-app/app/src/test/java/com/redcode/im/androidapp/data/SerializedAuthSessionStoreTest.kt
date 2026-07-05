package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.auth.InMemorySecureKeyValueStore
import com.redcode.im.androidapp.data.auth.SerializedAuthSessionStore
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SerializedAuthSessionStoreTest {
    @Test
    fun save_persistsSessionAndRestoresFromSameKeyValueStore() =
        runTest {
            val keyValueStore = InMemorySecureKeyValueStore()
            val store = SerializedAuthSessionStore(keyValueStore)
            val session = session()

            store.save(session)
            val restored = SerializedAuthSessionStore(keyValueStore)

            assertEquals(session, store.session.value)
            assertEquals(session, restored.session.value)
            assertTrue(keyValueStore.getString("auth_session")!!.contains("access-token"))
        }

    @Test
    fun clear_removesPersistedSession() =
        runTest {
            val keyValueStore = InMemorySecureKeyValueStore()
            val store = SerializedAuthSessionStore(keyValueStore)
            store.save(session())

            store.clear()
            val restored = SerializedAuthSessionStore(keyValueStore)

            assertNull(store.session.value)
            assertNull(restored.session.value)
            assertNull(keyValueStore.getString("auth_session"))
        }

    @Test
    fun invalidPayload_isDiscarded() {
        val keyValueStore = InMemorySecureKeyValueStore(mapOf("auth_session" to "{broken"))

        val store = SerializedAuthSessionStore(keyValueStore)

        assertNull(store.session.value)
        assertNull(keyValueStore.getString("auth_session"))
    }

    private fun session(): AuthSession =
        AuthSession(
            user =
                AuthUser(
                    id = "user-1",
                    accountName = "tester",
                    displayName = "Tester",
                    avatarUrl = "https://asset.example/tester.png",
                ),
            tokens =
                TokenPair(
                    accessToken = "access-token",
                    refreshToken = "refresh-token",
                ),
        )
}
