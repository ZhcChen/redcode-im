package com.redcode.im.androidapp.data.preferences

import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update

class InMemoryUserPreferenceStore(
    initialAcceptedTerms: Boolean = false,
) : UserPreferenceStore {
    private val accepted = MutableStateFlow(initialAcceptedTerms)
    private val roomPreferences = MutableStateFlow<Map<String, ChatRoomPreferences>>(emptyMap())
    override val acceptedTerms = accepted.asStateFlow()

    override suspend fun setAcceptedTerms(accepted: Boolean) {
        this.accepted.value = accepted
    }

    override fun chatPreferences(roomId: String) =
        roomPreferences.map { preferences ->
            preferences[roomId] ?: ChatRoomPreferences()
        }

    override suspend fun setChatPreferences(roomId: String, preferences: ChatRoomPreferences) {
        roomPreferences.value = roomPreferences.value + (roomId to preferences.normalized())
    }

    override suspend fun updateChatPreferences(
        roomId: String,
        transform: (ChatRoomPreferences) -> ChatRoomPreferences,
    ): ChatRoomPreferences {
        var updated = ChatRoomPreferences()
        roomPreferences.update { current ->
            updated = transform(current[roomId] ?: ChatRoomPreferences()).normalized()
            current + (roomId to updated)
        }
        return updated
    }
}
