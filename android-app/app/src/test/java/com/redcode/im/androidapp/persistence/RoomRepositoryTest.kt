package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RoomRepositoryTest {
    @Test
    fun roomChatRepository_sendsTrimsMarksReadAndPrunes() =
        runTest {
            val dao = FakeChatDao()
            val repository = RoomChatRepository(dao, maxMessagesPerRoom = 2)
            repository.upsertSummary(
                ChatSummary(
                    roomId = "room-1",
                    title = "Room",
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = "seed",
                    unreadCount = 7,
                    updatedAt = Instant.ofEpochMilli(1),
                ),
            )

            val sent = repository.sendText("room-1", "user-1", "Alice", "  hello  ")
            repository.replaceMessages(
                "room-1",
                listOf(message("m1", 1), message("m2", 2), message("m3", 3), sent),
            )
            repository.markRead("room-1")

            assertEquals("hello", sent.text)
            assertEquals(listOf("m3", sent.id), repository.messages("room-1").first().map { it.id })
            assertEquals(0, repository.chats.first().single().unreadCount)
        }

    @Test
    fun roomChatRepository_rejectsBlankAndClears() =
        runTest {
            val repository = RoomChatRepository(FakeChatDao())

            val error = runCatching { repository.sendText("room-1", "user-1", "Alice", " ") }.exceptionOrNull()
            repository.clear()

            assertTrue(error is IllegalArgumentException)
            assertEquals(emptyList<ChatSummary>(), repository.chats.first())
        }

    @Test
    fun roomContactsRepository_searchesUpsertsRemovesAndClears() =
        runTest {
            val repository = RoomContactsRepository(FakeContactDao())

            assertEquals(emptyList<Contact>(), repository.search(" "))
            repository.replaceContacts(listOf(Contact("user-b", "bob", "Bob"), Contact("user-a", "alice", "Alice")))
            repository.addLocalContact(Contact("user-c", "charlie", "Charlie"))
            repository.addLocalContact(Contact("user-c", "charlie2", "Charlie B"))

            assertEquals(listOf("alice", "bob", "charlie2"), repository.contacts.first().map { it.accountName })
            assertEquals("charlie2", repository.search("Charlie B").single().accountName)

            repository.remove("user-b")
            assertEquals(listOf("alice", "charlie2"), repository.contacts.first().map { it.accountName })

            repository.clear()
            assertEquals(emptyList<Contact>(), repository.contacts.first())
        }

    private fun message(id: String, millis: Long): ChatMessage =
        ChatMessage(
            id = id,
            roomId = "room-1",
            senderId = "user-1",
            senderName = "Alice",
            text = id,
            status = MessageStatus.Sent,
            createdAt = Instant.ofEpochMilli(millis),
        )
}

private class FakeChatDao : ChatDao {
    private val summaries = MutableStateFlow<List<ChatSummaryEntity>>(emptyList())
    private val messages = MutableStateFlow<Map<String, List<ChatMessageEntity>>>(emptyMap())

    override fun observeSummaries(): Flow<List<ChatSummaryEntity>> =
        summaries.map { list ->
            list.sortedWith(
                compareByDescending<ChatSummaryEntity> { it.isPinned }
                    .thenByDescending { it.updatedAtMillis }
                    .thenBy { it.title.lowercase() },
            )
        }

    override fun observeMessages(roomId: String): Flow<List<ChatMessageEntity>> =
        messages.map { byRoom -> byRoom[roomId].orEmpty().sortedBy { it.createdAtMillis } }

    override suspend fun upsertSummary(summary: ChatSummaryEntity) {
        summaries.value = summaries.value.filterNot { it.roomId == summary.roomId } + summary
    }

    override suspend fun upsertMessage(message: ChatMessageEntity) {
        val next = (messages.value[message.roomId].orEmpty().filterNot { it.id == message.id } + message)
        messages.value = messages.value + (message.roomId to next)
    }

    override suspend fun upsertMessages(messages: List<ChatMessageEntity>) {
        messages.forEach { upsertMessage(it) }
    }

    override suspend fun markRead(roomId: String) {
        summaries.value = summaries.value.map { if (it.roomId == roomId) it.copy(unreadCount = 0) else it }
    }

    override suspend fun pruneMessages(roomId: String, keep: Int) {
        val kept = messages.value[roomId].orEmpty().sortedByDescending { it.createdAtMillis }.take(keep)
        messages.value = messages.value + (roomId to kept)
    }

    override suspend fun clearMessages() {
        messages.value = emptyMap()
    }

    override suspend fun clearSummaries() {
        summaries.value = emptyList()
    }
}

private class FakeContactDao : ContactDao {
    private val contacts = MutableStateFlow<List<ContactEntity>>(emptyList())

    override fun observeContacts(): Flow<List<ContactEntity>> =
        contacts.map { list -> list.sortedBy { it.displayName.lowercase() } }

    override suspend fun search(query: String): List<ContactEntity> =
        contacts.value
            .filter {
                it.accountName.contains(query, ignoreCase = true) ||
                    it.displayName.contains(query, ignoreCase = true)
            }
            .sortedBy { it.displayName.lowercase() }

    override suspend fun upsert(contact: ContactEntity) {
        contacts.value = contacts.value.filterNot { it.userId == contact.userId } + contact
    }

    override suspend fun upsertAll(contacts: List<ContactEntity>) {
        contacts.forEach { upsert(it) }
    }

    override suspend fun remove(userId: String) {
        contacts.value = contacts.value.filterNot { it.userId == userId }
    }

    override suspend fun clear() {
        contacts.value = emptyList()
    }
}
