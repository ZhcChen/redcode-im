package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.core.model.redCodeDefaultStickerPacks
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.data.emoji.EmojiRepository
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.feature.chat.AudioPlaybackController
import com.redcode.im.androidapp.feature.chat.AudioPlaybackPhase
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.feature.chat.ChatListViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
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
    fun chatDetail_emojiPanelInsertsDraftAndPanelsAreExclusive() =
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

            viewModel.toggleEmojiPanel()
            viewModel.insertEmoji("😀")
            viewModel.toggleStickerPanel()
            advanceUntilIdle()

            assertEquals("😀", viewModel.uiState.value.draft)
            assertEquals(false, viewModel.uiState.value.isEmojiPanelVisible)
            assertEquals(true, viewModel.uiState.value.isStickerPanelVisible)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_loadsStickerPacksWhenStickerPanelOpens() =
        runTest {
            val emojiRepository =
                FakeEmojiRepository(
                    packs =
                        listOf(
                            StickerPack(
                                id = "remote-pack",
                                name = "远端贴纸",
                                items =
                                    listOf(
                                        StickerItem(id = "remote-ok", label = "OK", imageObjectKey = "emoji-items/remote-ok.gif"),
                                    ),
                            ),
                        ),
                )
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    emojiRepository = emojiRepository,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.toggleStickerPanel()
            advanceUntilIdle()

            assertEquals(1, emojiRepository.loadCount)
            assertEquals("remote-pack", viewModel.uiState.value.stickerPacks.single().id)
            assertEquals(false, viewModel.uiState.value.isLoadingStickers)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_loadStickerPacksFailureFallsBackToDefaultStickers() =
        runTest {
            val emojiRepository = FakeEmojiRepository(loadError = IllegalStateException("remote emoji unavailable"))
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    emojiRepository = emojiRepository,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.toggleStickerPanel()
            advanceUntilIdle()

            assertEquals(redCodeDefaultStickerPacks, viewModel.uiState.value.stickerPacks)
            assertEquals(false, viewModel.uiState.value.isLoadingStickers)
            assertEquals("remote emoji unavailable", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_sendStickerUsesCachedEmojiUploadPath() =
        runTest {
            val repository = InMemoryChatRepository()
            val sticker = StickerItem(id = "remote-ok", label = "OK", imageObjectKey = "emoji-items/remote-ok.gif")
            val emojiRepository =
                FakeEmojiRepository(
                    uploadPayload =
                        AttachmentUploadPayload(
                            bytes = "gif".encodeToByteArray(),
                            fileName = "remote-ok.gif",
                            mime = "image/gif",
                        ),
                )
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    emojiRepository = emojiRepository,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onDraftChange("caption")
            viewModel.sendSticker(sticker)
            advanceUntilIdle()

            val sent = viewModel.uiState.value.messages.last()
            assertEquals(listOf(sticker), emojiRepository.preparedStickers)
            assertEquals("", viewModel.uiState.value.draft)
            assertEquals(false, viewModel.uiState.value.isUploadingAttachment)
            assertEquals("caption [图片]", sent.text)
            assertEquals("local/remote-ok.gif", sent.parts.single { it.type == MessagePartType.Image }.attachment?.key)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_sendStickerFailureRestoresUploadingAndKeepsDraft() =
        runTest {
            val repository = InMemoryChatRepository()
            val sticker = StickerItem(id = "remote-ok", label = "OK", imageObjectKey = "emoji-items/remote-ok.gif")
            val emojiRepository = FakeEmojiRepository(prepareError = IllegalStateException("download failed"))
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    emojiRepository = emojiRepository,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            val originalMessages = viewModel.uiState.value.messages.size
            viewModel.onDraftChange("caption")
            viewModel.sendSticker(sticker)
            advanceUntilIdle()

            assertEquals("caption", viewModel.uiState.value.draft)
            assertEquals(false, viewModel.uiState.value.isUploadingAttachment)
            assertEquals("download failed", viewModel.uiState.value.errorMessage)
            assertEquals(originalMessages, viewModel.uiState.value.messages.size)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_sendStickerWithoutResourceKeepsDraftAndShowsError() =
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

            viewModel.onDraftChange("caption")
            viewModel.sendSticker(StickerItem(id = "broken", label = "Broken"))
            advanceUntilIdle()

            assertEquals("caption", viewModel.uiState.value.draft)
            assertEquals(false, viewModel.uiState.value.isUploadingAttachment)
            assertEquals("贴纸资源不可用", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_chatPreferencesPersistPerRoom() =
        runTest {
            val store = InMemoryUserPreferenceStore()
            val roomA =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-a",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    chatPreferenceStore = store,
                )
            val roomB =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-b",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    chatPreferenceStore = store,
                )
            val collectA = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { roomA.uiState.collect() }
            val collectB = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { roomB.uiState.collect() }
            advanceUntilIdle()

            roomA.setChatBackground("warm")
            roomA.setFontScale(2.0f)
            roomA.toggleEnterToSend()
            roomA.toggleAutoDownloadMedia()
            advanceUntilIdle()

            val preferences = roomA.uiState.value.chatPreferences
            assertEquals("warm", preferences.backgroundKey)
            assertEquals(ChatRoomPreferences.MAX_FONT_SCALE, preferences.fontScale)
            assertEquals(true, preferences.enterToSend)
            assertEquals(true, preferences.autoDownloadMedia)
            assertEquals(ChatRoomPreferences(), roomB.uiState.value.chatPreferences)
            collectA.cancel()
            collectB.cancel()
        }

    @Test
    fun chatDetail_chatPreferencesMergeRapidUpdates() =
        runTest {
            val store = InMemoryUserPreferenceStore()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = InMemoryChatRepository(),
                    roomId = "room-a",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                    chatPreferenceStore = store,
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.setChatBackground("warm")
            viewModel.setFontScale(1.2f)
            viewModel.toggleEnterToSend()
            viewModel.toggleAutoDownloadMedia()
            advanceUntilIdle()

            val preferences = viewModel.uiState.value.chatPreferences
            assertEquals("warm", preferences.backgroundKey)
            assertEquals(1.2f, preferences.fontScale, 0.001f)
            assertEquals(true, preferences.enterToSend)
            assertEquals(true, preferences.autoDownloadMedia)
            collectJob.cancel()
        }

    @Test
    fun chatDetail_autoDownloadDeduplicatesAttachments() =
        runTest {
            val repository = CountingCacheChatRepository()
            val viewModel =
                ChatDetailViewModel(
                    chatRepository = repository,
                    roomId = "room-general",
                    currentUserId = "user-me",
                    currentUserName = "Me",
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            val attachment =
                MessageAttachment(
                    key = "messages/room-general/a.png",
                    name = "a.png",
                    mime = "image/png",
                )
            advanceUntilIdle()

            viewModel.autoDownloadMissingAttachments(listOf(attachment, attachment, attachment.copy(localPath = "/tmp/a.png")))
            advanceUntilIdle()

            assertEquals(listOf("messages/room-general/a.png"), repository.cachedKeys)
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

    private class FakeEmojiRepository(
        private val packs: List<StickerPack> = emptyList(),
        private val uploadPayload: AttachmentUploadPayload? = null,
        private val loadError: Throwable? = null,
        private val prepareError: Throwable? = null,
    ) : EmojiRepository {
        var loadCount = 0
        val preparedStickers = mutableListOf<StickerItem>()

        override suspend fun loadStickerPacks(): List<StickerPack> {
            loadCount += 1
            loadError?.let { throw it }
            return packs
        }

        override suspend fun prepareStickerUpload(sticker: StickerItem): AttachmentUploadPayload? {
            preparedStickers += sticker
            prepareError?.let { throw it }
            return uploadPayload
        }
    }

    private class CountingCacheChatRepository : ChatRepository {
        val cachedKeys = mutableListOf<String>()
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

        override suspend fun downloadAndCacheAttachment(
            roomId: String,
            attachment: MessageAttachment,
            forceRefresh: Boolean,
        ): MessageAttachment {
            cachedKeys += attachment.key
            return attachment.copy(localPath = "/tmp/${attachment.displayName}")
        }

        override suspend fun markRead(roomId: String) = Unit
    }
}
