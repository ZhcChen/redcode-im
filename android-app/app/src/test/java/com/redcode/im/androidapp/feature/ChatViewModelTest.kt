package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.feature.chat.AudioPlaybackController
import com.redcode.im.androidapp.feature.chat.AudioPlaybackPhase
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.feature.chat.ChatListViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun chatList_exposesSeedConversation() =
        runTest {
            val viewModel = ChatListViewModel(InMemoryChatRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.chats.collect() }
            advanceUntilIdle()

            assertEquals("RedCode 测试群", viewModel.chats.value.single().title)
            collectJob.cancel()
        }

    @Test
    fun chatList_togglePinnedAndMutedUpdatesConversation() =
        runTest {
            val viewModel = ChatListViewModel(InMemoryChatRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.chats.collect() }
            advanceUntilIdle()

            viewModel.togglePinned(viewModel.chats.value.single())
            advanceUntilIdle()
            viewModel.toggleMuted(viewModel.chats.value.single())
            advanceUntilIdle()

            val chat = viewModel.chats.value.single()
            assertEquals(true, chat.isPinned)
            assertEquals(true, chat.isMuted)
            assertEquals(null, viewModel.errorMessage.value)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_sendsDraftAndClearsInput() =
        runTest {
            val repository = InMemoryChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            val seed = viewModel.uiState.value.messages.single()
            viewModel.quoteMessage(seed)
            viewModel.onDraftChange("hello")
            viewModel.sendDraft()
            advanceUntilIdle()

            assertEquals("", viewModel.uiState.value.draft)
            assertEquals(null, viewModel.uiState.value.quotedMessage)
            val sent = viewModel.uiState.value.messages.last()
            assertEquals("hello", sent.text)
            assertEquals(seed.id, sent.quotedMessage?.id)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_uploadsAttachmentAndClearsInput() =
        runTest {
            val repository = InMemoryChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onDraftChange("caption")
            viewModel.uploadAndSendAttachment(
                file =
                    AttachmentUploadPayload(
                        bytes = "file".encodeToByteArray(),
                        fileName = "report.pdf",
                        mime = "application/pdf",
                    ),
                type = MessagePartType.File,
            )
            advanceUntilIdle()

            val sent = viewModel.uiState.value.messages.last()
            assertEquals("", viewModel.uiState.value.draft)
            assertEquals(false, viewModel.uiState.value.isUploadingAttachment)
            assertEquals("caption [文件]", sent.text)
            assertEquals("report.pdf", sent.parts.single { it.type == MessagePartType.File }.attachment?.displayName)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_attachmentPickerCancellationDoesNotPolluteDraft() =
        runTest {
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onDraftChange("keep me")
            viewModel.onAttachmentPickerCancelled()
            advanceUntilIdle()

            assertEquals("keep me", viewModel.uiState.value.draft)
            assertEquals(null, viewModel.uiState.value.errorMessage)
            assertEquals(false, viewModel.uiState.value.isUploadingAttachment)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_audioPlaybackLoadsPlaysAndPauses() =
        runTest {
            val audioPlayer = FakeAudioPlaybackController()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    audioPlaybackController = audioPlayer,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            val attachment =
                MessageAttachment(
                    key = "messages/room-general/audio.m4a",
                    name = "audio.m4a",
                    mime = "audio/mp4",
                    localPath = "/tmp/audio.m4a",
                )
            advanceUntilIdle()

            viewModel.playOrPauseAudio(attachment)
            advanceUntilIdle()

            val playing = viewModel.uiState.value.audioPlaybackStatus.getValue(attachment.key)
            assertEquals(AudioPlaybackPhase.Playing, playing.phase)
            assertEquals("/tmp/audio.m4a", playing.localPath)
            assertEquals(listOf("/tmp/audio.m4a"), audioPlayer.playedPaths)

            viewModel.playOrPauseAudio(attachment)
            advanceUntilIdle()

            val paused = viewModel.uiState.value.audioPlaybackStatus.getValue(attachment.key)
            assertEquals(AudioPlaybackPhase.Paused, paused.phase)
            assertEquals(1, audioPlayer.pauseCount)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_audioPlaybackFailureShowsFailedState() =
        runTest {
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    audioPlaybackController = FakeAudioPlaybackController(shouldFail = true),
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            val attachment =
                MessageAttachment(
                    key = "messages/room-general/audio.m4a",
                    name = "audio.m4a",
                    mime = "audio/mp4",
                    localPath = "/tmp/audio.m4a",
                )
            advanceUntilIdle()

            viewModel.playOrPauseAudio(attachment)
            advanceUntilIdle()

            val playback = viewModel.uiState.value.audioPlaybackStatus.getValue(attachment.key)
            assertEquals(AudioPlaybackPhase.Failed, playback.phase)
            assertEquals("fake playback failure", playback.message)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_blankDraftShowsErrorAndMarkReadClearsUnread() =
        runTest {
            val repository = InMemoryChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onDraftChange(" ")
            viewModel.sendDraft()
            viewModel.markRead()
            advanceUntilIdle()

            assertEquals("消息不能为空", viewModel.uiState.value.errorMessage)
            assertEquals(0, repository.chats.first().single().unreadCount)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_loadOlderDisablesWhenRepositoryHasNoMoreMessages() =
        runTest {
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.loadOlderMessages()
            advanceUntilIdle()

            assertEquals(false, viewModel.uiState.value.hasOlderMessages)
            assertEquals(false, viewModel.uiState.value.isLoadingOlder)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_searchesLocalMessagesAndClearsResults() =
        runTest {
            val repository = InMemoryChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onDraftChange("search target")
            viewModel.sendDraft()
            advanceUntilIdle()
            viewModel.onSearchQueryChange("target")
            viewModel.searchMessages()
            advanceUntilIdle()

            assertEquals(listOf("search target"), viewModel.uiState.value.searchResults.map { it.text })
            viewModel.clearSearch()
            assertEquals("", viewModel.uiState.value.searchQuery)
            assertEquals(emptyList<Any>(), viewModel.uiState.value.searchResults)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_messageActionsUpdateLocalState() =
        runTest {
            val repository = InMemoryChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()
            val seed = viewModel.uiState.value.messages.single()

            viewModel.toggleMessagePinned(seed)
            advanceUntilIdle()
            val pinned = viewModel.uiState.value.messages.single()
            viewModel.toggleThumbReaction(pinned)
            advanceUntilIdle()
            val reacted = viewModel.uiState.value.messages.single()
            viewModel.deleteMessage(reacted.id)
            advanceUntilIdle()

            val deleted = viewModel.uiState.value.messages.single()
            assertEquals(true, pinned.isPinned)
            assertEquals("👍", reacted.reactions.single().reactionKey)
            assertEquals(true, reacted.reactions.single().hasSelf)
            assertEquals(true, deleted.isDeleted)
            assertEquals("消息已删除", deleted.text)
            collectJob.cancel()
        }

    private class FakeAudioPlaybackController(
        private val shouldFail: Boolean = false,
    ) : AudioPlaybackController {
        val playedPaths = mutableListOf<String>()
        var pauseCount = 0

        override suspend fun play(localPath: String, onCompleted: () -> Unit) {
            if (shouldFail) error("fake playback failure")
            playedPaths += localPath
        }

        override fun pause() {
            pauseCount += 1
        }

        override fun stop() = Unit
    }
}
