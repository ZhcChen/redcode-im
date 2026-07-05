package com.redcode.im.androidapp.persistence

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RoomPersistenceTest {
    private lateinit var database: RedCodeDatabase

    @Before
    fun setUp() {
        database =
            Room
                .inMemoryDatabaseBuilder(
                    ApplicationProvider.getApplicationContext(),
                    RedCodeDatabase::class.java,
                )
                .allowMainThreadQueries()
                .build()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun chatDao_ordersSummariesAndPrunesOldMessages() =
        runTest {
            val chatDao = database.chatDao()
            val repository = RoomChatRepository(chatDao, maxMessagesPerRoom = 2)
            repository.upsertSummary(
                ChatSummary(
                    roomId = "room-a",
                    title = "A",
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = "old",
                    updatedAt = Instant.ofEpochMilli(1),
                ),
            )
            repository.upsertSummary(
                ChatSummary(
                    roomId = "room-b",
                    title = "B",
                    roomType = ChatRoomType.Direct,
                    lastMessagePreview = "new",
                    isPinned = true,
                    updatedAt = Instant.ofEpochMilli(2),
                ),
            )

            val summaries = repository.chats.first()
            assertEquals(listOf("room-b", "room-a"), summaries.map { it.roomId })

            repository.replaceMessages(
                roomId = "room-a",
                messages =
                    listOf(
                        message("m1", 1),
                        message("m2", 2),
                        message("m3", 3),
                    ),
            )

            assertEquals(listOf("m2", "m3"), repository.messages("room-a").first().map { it.id })
        }

    @Test
    fun roomChatRepository_sendsTextAndMarksRead() =
        runTest {
            val repository = RoomChatRepository(database.chatDao(), maxMessagesPerRoom = 5)

            repository.upsertSummary(
                ChatSummary(
                    roomId = "room-a",
                    title = "A",
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = "seed",
                    unreadCount = 9,
                ),
            )
            val sent = repository.sendText("room-a", "user-1", "Alice", "  hello  ")
            repository.markRead("room-a")

            assertEquals("hello", sent.text)
            assertTrue(repository.messages("room-a").first().any { it.text == "hello" })
            assertEquals(0, repository.chats.first().single().unreadCount)
        }

    @Test
    fun contactDao_searchesUpsertsRemovesAndClears() =
        runTest {
            val repository = RoomContactsRepository(database.contactDao())

            repository.replaceContacts(
                listOf(
                    Contact("user-b", "bob", "Bob"),
                    Contact("user-a", "alice", "Alice"),
                ),
            )
            repository.addLocalContact(Contact("user-c", "charlie", "Charlie"))

            assertEquals(listOf("Alice", "Bob", "Charlie"), repository.contacts.first().map { it.displayName })
            assertEquals("alice", repository.search("ALI").single().accountName)

            repository.remove("user-b")
            assertEquals(listOf("alice", "charlie"), repository.contacts.first().map { it.accountName })

            repository.clear()
            assertEquals(emptyList<Contact>(), repository.contacts.first())
        }

    private fun message(id: String, millis: Long): ChatMessage =
        ChatMessage(
            id = id,
            roomId = "room-a",
            senderId = "user-1",
            senderName = "Alice",
            text = id,
            status = MessageStatus.Sent,
            createdAt = Instant.ofEpochMilli(millis),
        )
}
