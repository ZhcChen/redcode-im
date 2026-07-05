package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class SerializedAuthSessionStore(
    private val keyValueStore: SecureKeyValueStore,
    private val json: Json = Json { ignoreUnknownKeys = true },
) : AuthSessionStore {
    private val state = MutableStateFlow(readStoredSession())
    override val session = state.asStateFlow()

    override suspend fun save(session: AuthSession) {
        val encoded = json.encodeToString(AuthSessionSnapshot.fromDomain(session))
        keyValueStore.putString(STORAGE_KEY, encoded)
        state.value = session
    }

    override suspend fun clear() {
        keyValueStore.remove(STORAGE_KEY)
        state.value = null
    }

    private fun readStoredSession(): AuthSession? {
        val encoded = keyValueStore.getString(STORAGE_KEY) ?: return null
        return try {
            json.decodeFromString<AuthSessionSnapshot>(encoded).toDomain()
        } catch (_: SerializationException) {
            keyValueStore.remove(STORAGE_KEY)
            null
        } catch (_: IllegalArgumentException) {
            keyValueStore.remove(STORAGE_KEY)
            null
        }
    }

    companion object {
        private const val STORAGE_KEY = "auth_session"
    }
}
