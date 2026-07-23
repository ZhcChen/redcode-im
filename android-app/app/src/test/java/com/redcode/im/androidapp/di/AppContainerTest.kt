package com.redcode.im.androidapp.di

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.emoji.EmojiRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppContainerTest {
    @Test
    fun clearLocalSessionState_runsAllCleanupsBeforeSurfacingFailure() =
        runTest {
            val emojiRepository = RecordingEmojiRepository()
            val container =
                AppContainer(
                    environment = RedCodeEnvironment.localEmulator(),
                    chatRepository = FailingClearChatRepository(),
                    emojiRepository = emojiRepository,
                )

            val error = runCatching { container.clearLocalSessionState() }.exceptionOrNull()

            assertTrue(error is IllegalStateException)
            assertEquals(true, emojiRepository.cleared)
        }

    private class FailingClearChatRepository : ChatRepository {
        override val chats: Flow<List<ChatSummary>> = flowOf(emptyList())

        override fun messages(roomId: String): Flow<List<ChatMessage>> =
            flowOf(emptyList())

        override suspend fun sendText(
            roomId: String,
            senderId: String,
            senderName: String,
            text: String,
            quotedMessageId: String?,
        ): ChatMessage =
            error("not used")

        override suspend fun markRead(roomId: String) = Unit

        override suspend fun clearLocalState() {
            error("chat clear failed")
        }
    }

    private class RecordingEmojiRepository : EmojiRepository {
        var cleared = false

        override suspend fun loadStickerPacks(): List<StickerPack> =
            emptyList()

        override suspend fun prepareStickerUpload(sticker: StickerItem) =
            null

        override suspend fun clearLocalState() {
            cleared = true
        }
    }
}
