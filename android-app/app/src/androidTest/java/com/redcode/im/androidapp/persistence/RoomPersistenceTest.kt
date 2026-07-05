package com.redcode.im.androidapp.persistence

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
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
    fun roomChatRepository_searchesCachedMessages() =
        runTest {
            val repository = RoomChatRepository(database.chatDao(), maxMessagesPerRoom = 5)
            repository.replaceMessages(
                roomId = "room-a",
                messages =
                    listOf(
                        message("m1", 1).copy(text = "alpha target", senderName = "Alice"),
                        message("m2", 2).copy(text = "beta", senderName = "Bob"),
                    ),
            )

            val byText = repository.searchMessages("room-a", "target")
            val bySender = repository.searchMessages("room-a", "bob")

            assertEquals(listOf("m1"), byText.map { it.id })
            assertEquals(listOf("m2"), bySender.map { it.id })
        }

    @Test
    fun roomChatRepository_appliesRealtimeMessagesAndRoomCleanup() =
        runTest {
            val repository = RoomChatRepository(database.chatDao(), maxMessagesPerRoom = 5)
            repository.upsertSummary(
                ChatSummary(
                    roomId = "room-a",
                    title = "Room A",
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = "seed",
                    unreadCount = 1,
                    updatedAt = Instant.ofEpochMilli(1),
                ),
            )
            val incoming =
                ChatMessage(
                    id = "m-realtime",
                    roomId = "room-a",
                    senderId = "user-other",
                    senderName = "Other",
                    text = "new",
                    status = MessageStatus.Sent,
                    createdAt = Instant.ofEpochMilli(2),
                )

            repository.applyIncomingMessage(incoming, currentUserId = "user-me")
            repository.applyIncomingMessage(incoming, currentUserId = "user-me")

            val summary = repository.chats.first().single()
            assertEquals("new", summary.lastMessagePreview)
            assertEquals(2, summary.unreadCount)
            assertEquals(listOf("m-realtime"), repository.messages("room-a").first().map { it.id })

            repository.updateMessagePin(
                roomId = "room-a",
                messageId = "m-realtime",
                pinned = true,
                pinnedAt = Instant.ofEpochMilli(3),
                pinnedBy = "user-me",
            )
            repository.updateMessageReactions(
                roomId = "room-a",
                messageId = "m-realtime",
                reactions = listOf(MessageReactionSummary(reactionKey = "👍", count = 2L, hasSelf = true)),
            )
            val updated = repository.messages("room-a").first().single()
            assertEquals(true, updated.isPinned)
            assertEquals("user-me", updated.pinnedBy)
            assertEquals("👍", updated.reactions.single().reactionKey)

            repository.markMessageDeleted(roomId = "room-a", messageId = "m-realtime")
            val deleted = repository.messages("room-a").first().single()
            assertEquals("消息已删除", deleted.text)
            assertEquals(true, deleted.isDeleted)
            assertEquals(false, deleted.isPinned)

            repository.removeRoom("room-a")
            assertEquals(emptyList<ChatSummary>(), repository.chats.first())
            assertEquals(emptyList<ChatMessage>(), repository.messages("room-a").first())
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

    @Test
    fun roomDao_persistsGroupRoomsMembersAndSettings() =
        runTest {
            val repository = RoomGroupRepository(database.roomDao())
            val room =
                RoomInfo(
                    id = "room-a",
                    name = "A Group",
                    roomType = "group",
                    description = "desc",
                    ownerId = "user-owner",
                    updatedAt = Instant.ofEpochMilli(2),
                )

            repository.replaceRooms(listOf(room))
            repository.replaceMembers(
                "room-a",
                listOf(
                    RoomMember(userId = "user-b", username = "bob", role = "member"),
                    RoomMember(userId = "user-owner", username = "owner", role = "owner"),
                ),
            )
            repository.upsertSettings(
                GroupSettingsSnapshot(
                    GroupSettingsInfo(
                        roomId = "room-a",
                        joinApprovalRequired = true,
                        globalMuteEnabled = true,
                        maxMembers = 300,
                    ),
                ),
            )

            assertEquals(listOf("room-a"), repository.rooms.first().map { it.id })
            assertEquals(listOf("owner", "bob"), repository.members("room-a").first().map { it.username })
            assertEquals(true, repository.settings("room-a").first()?.settings?.joinApprovalRequired)
            assertEquals(300, repository.settings("room-a").first()?.settings?.maxMembers)

            repository.removeMember("room-a", "user-b")
            assertEquals(listOf("user-owner"), repository.members("room-a").first().map { it.userId })

            repository.removeRoom("room-a")
            assertEquals(emptyList<RoomInfo>(), repository.rooms.first())
            assertEquals(emptyList<RoomMember>(), repository.members("room-a").first())
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
