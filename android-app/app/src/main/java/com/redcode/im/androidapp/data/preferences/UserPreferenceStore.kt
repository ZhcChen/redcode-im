package com.redcode.im.androidapp.data.preferences

import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first

interface ChatPreferenceStore {
    fun chatPreferences(roomId: String): Flow<ChatRoomPreferences>

    suspend fun setChatPreferences(roomId: String, preferences: ChatRoomPreferences)

    suspend fun updateChatPreferences(
        roomId: String,
        transform: (ChatRoomPreferences) -> ChatRoomPreferences,
    ): ChatRoomPreferences {
        val updated = transform(chatPreferences(roomId).first()).normalized()
        setChatPreferences(roomId, updated)
        return updated
    }
}

interface UserPreferenceStore : ChatPreferenceStore {
    val acceptedTerms: Flow<Boolean>

    suspend fun setAcceptedTerms(accepted: Boolean)
}
