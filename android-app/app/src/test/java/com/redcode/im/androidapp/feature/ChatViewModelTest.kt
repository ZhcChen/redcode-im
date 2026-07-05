package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
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
}
