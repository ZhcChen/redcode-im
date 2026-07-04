package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatRepositoryTest {
    @Test
    fun sendText_updatesMessagesAndSummary() =
        runTest {
            val repository = InMemoryChatRepository(maxMessagesPerRoom = 3)

            repository.sendText("room-general", "user-a", "Alice", "  hello  ")

            val messages = repository.messages("room-general").first()
            assertEquals("hello", messages.last().text)
            assertEquals("hello", repository.chats.first().single().lastMessagePreview)
        }

    @Test
    fun sendText_keepsRecentMessagesPerRoom() =
        runTest {
            val repository = InMemoryChatRepository(maxMessagesPerRoom = 2)

            repository.sendText("room-general", "user-a", "Alice", "one")
            repository.sendText("room-general", "user-a", "Alice", "two")
            repository.sendText("room-general", "user-a", "Alice", "three")
            repository.sendText("room-new", "user-a", "Alice", "new room message")

            val messages = repository.messages("room-general").first()
            assertEquals(listOf("two", "three"), messages.map { it.text })
            assertEquals("new room message", repository.messages("room-new").first().single().text)
        }

    @Test
    fun markRead_clearsUnreadCount() =
        runTest {
            val repository = InMemoryChatRepository()

            repository.markRead("room-general")
            repository.markRead("missing-room")

            assertEquals(0, repository.chats.first().single().unreadCount)
        }

    @Test
    fun sendText_rejectsBlankMessage() =
        runTest {
            val repository = InMemoryChatRepository()

            assertTrue(
                runCatching { repository.sendText("room-general", "user-a", "Alice", " ") }
                    .exceptionOrNull() is IllegalArgumentException,
            )
        }
}
