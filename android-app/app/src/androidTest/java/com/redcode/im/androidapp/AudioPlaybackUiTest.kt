package com.redcode.im.androidapp

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.feature.chat.AudioPlaybackController
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.ui.theme.RedCodeTheme
import java.time.Instant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class AudioPlaybackUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun chatDetailCanTriggerAudioPlayAndPause() {
        val attachment =
            MessageAttachment(
                key = "messages/room-a/audio.m4a",
                name = "audio.m4a",
                mime = "audio/mp4",
                localPath = "/tmp/audio.m4a",
            )
        val audioPlayer = FakeAudioPlaybackController()
        val viewModel =
            ChatDetailViewModel(
                chatRepository = SingleAudioMessageRepository(attachment),
                roomId = "room-a",
                currentUserId = "user-me",
                currentUserName = "Me",
                audioPlaybackController = audioPlayer,
            )

        composeRule.setContent {
            RedCodeTheme {
                ChatDetailScreen(
                    summary =
                        ChatSummary(
                            roomId = "room-a",
                            title = "语音测试",
                            roomType = ChatRoomType.Group,
                            lastMessagePreview = "[语音]",
                        ),
                    viewModel = viewModel,
                    onBack = {},
                )
            }
        }

        val playTag = "play-audio-${attachment.key.hashCode()}"
        composeRule.onNodeWithTag(playTag).assertIsDisplayed()
        composeRule.onNodeWithText("未播放").assertIsDisplayed()
        composeRule.onNodeWithTag(playTag).performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("播放中").assertIsDisplayed()
        composeRule.onNodeWithTag(playTag).performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("已暂停").assertIsDisplayed()

        assertEquals(listOf("/tmp/audio.m4a"), audioPlayer.playedPaths)
        assertEquals(1, audioPlayer.pauseCount)
    }

    private class SingleAudioMessageRepository(
        private val attachment: MessageAttachment,
    ) : ChatRepository {
        private val messages =
            MutableStateFlow(
                listOf(
                    ChatMessage(
                        id = "audio-1",
                        roomId = "room-a",
                        senderId = "user-a",
                        senderName = "Alice",
                        text = "[语音]",
                        status = MessageStatus.Sent,
                        createdAt = Instant.parse("2026-07-05T00:00:00Z"),
                        parts =
                            listOf(
                                MessagePart(
                                    position = 0,
                                    type = MessagePartType.Audio,
                                    attachment = attachment,
                                ),
                            ),
                    ),
                ),
            )

        override val chats: Flow<List<ChatSummary>> = MutableStateFlow(emptyList())

        override fun messages(roomId: String): Flow<List<ChatMessage>> = messages

        override suspend fun sendText(
            roomId: String,
            senderId: String,
            senderName: String,
            text: String,
            quotedMessageId: String?,
        ): ChatMessage = error("not used")

        override suspend fun downloadAndCacheAttachment(
            roomId: String,
            attachment: MessageAttachment,
            forceRefresh: Boolean,
        ): MessageAttachment = attachment.copy(localPath = attachment.localPath ?: "/tmp/audio.m4a")

        override suspend fun markRead(roomId: String) = Unit

        override suspend fun setReaction(
            roomId: String,
            messageId: String,
            reactionKey: String,
            selected: Boolean,
        ): List<MessageReactionSummary> = emptyList()
    }

    private class FakeAudioPlaybackController : AudioPlaybackController {
        val playedPaths = mutableListOf<String>()
        var pauseCount = 0

        override suspend fun play(localPath: String, onCompleted: () -> Unit) {
            playedPaths += localPath
        }

        override fun pause() {
            pauseCount += 1
        }

        override fun stop() = Unit
    }
}
