package com.redcode.im.androidapp.data.preferences

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import java.security.MessageDigest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.redCodePreferences by preferencesDataStore(name = "redcode_preferences")

class DataStoreUserPreferenceStore(
    context: Context,
) : UserPreferenceStore {
    private val dataStore = context.applicationContext.redCodePreferences
    private val json = Json { ignoreUnknownKeys = true }

    override val acceptedTerms: Flow<Boolean> =
        dataStore.data.map { preferences ->
            preferences[ACCEPTED_TERMS_KEY] ?: false
        }

    override suspend fun setAcceptedTerms(accepted: Boolean) {
        dataStore.edit { preferences ->
            preferences[ACCEPTED_TERMS_KEY] = accepted
        }
    }

    override fun chatPreferences(roomId: String): Flow<ChatRoomPreferences> =
        dataStore.data.map { preferences ->
            preferences[chatPreferencesKey(roomId)]
                ?.let(::decodeChatPreferences)
                ?: ChatRoomPreferences()
        }

    override suspend fun setChatPreferences(roomId: String, preferences: ChatRoomPreferences) {
        dataStore.edit { values ->
            values[chatPreferencesKey(roomId)] = json.encodeToString(preferences.normalized())
        }
    }

    override suspend fun updateChatPreferences(
        roomId: String,
        transform: (ChatRoomPreferences) -> ChatRoomPreferences,
    ): ChatRoomPreferences {
        var updated = ChatRoomPreferences()
        dataStore.edit { values ->
            val key = chatPreferencesKey(roomId)
            val current = values[key]?.let(::decodeChatPreferences) ?: ChatRoomPreferences()
            updated = transform(current).normalized()
            values[key] = json.encodeToString(updated)
        }
        return updated
    }

    internal suspend fun setRawChatPreferencesForTesting(roomId: String, raw: String) {
        dataStore.edit { values ->
            values[chatPreferencesKey(roomId)] = raw
        }
    }

    private fun decodeChatPreferences(raw: String): ChatRoomPreferences =
        try {
            json.decodeFromString<ChatRoomPreferences>(raw).normalized()
        } catch (_: SerializationException) {
            ChatRoomPreferences()
        } catch (_: IllegalArgumentException) {
            ChatRoomPreferences()
        }

    private fun chatPreferencesKey(roomId: String) =
        stringPreferencesKey("chat_preferences_${sha256(roomId)}")

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    companion object {
        private val ACCEPTED_TERMS_KEY = booleanPreferencesKey("accepted_terms")
    }
}
