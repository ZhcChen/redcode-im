package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import com.redcode.im.androidapp.data.chat.BackendChatMessagePreview
import com.redcode.im.androidapp.data.chat.BackendChatSummary
import com.redcode.im.androidapp.data.chat.ChatRemoteDataSource
import com.redcode.im.androidapp.data.contacts.BackendFriendInfo
import com.redcode.im.androidapp.data.contacts.BackendFriendRequest
import com.redcode.im.androidapp.data.contacts.BackendUser
import com.redcode.im.androidapp.data.contacts.EnsurePrivateChatResponse
import com.redcode.im.androidapp.data.contacts.FriendRemoteDataSource
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
    fun roomChatRepository_realtimeSelfAndOlderMessagesKeepUnreadAndPreviewStable() =
        runTest {
            val repository = RoomChatRepository(FakeChatDao())
            repository.applyIncomingMessage(
                ChatMessage(
                    id = "self-message",
                    roomId = "room-new",
                    senderId = "user-me",
                    senderName = "Me",
                    text = "mine",
                    status = MessageStatus.Sent,
                    createdAt = Instant.ofEpochMilli(10),
                ),
                currentUserId = "user-me",
            )
            repository.applyIncomingMessage(
                ChatMessage(
                    id = "older-message",
                    roomId = "room-new",
                    senderId = "user-other",
                    senderName = "Other",
                    text = "older",
                    status = MessageStatus.Sent,
                    createdAt = Instant.ofEpochMilli(1),
                ),
                currentUserId = "user-me",
            )

            val summary = repository.chats.first().single()
            assertEquals("mine", summary.lastMessagePreview)
            assertEquals(1, summary.unreadCount)
        }

    @Test
    fun roomContactsRepository_searchesUpsertsRemovesAndClears() =
        runTest {
            val repository = RoomContactsRepository(FakeContactDao())

            assertEquals(emptyList<Contact>(), repository.search(" "))
            repository.replaceContacts(listOf(Contact("user-b", "bob", "Bob"), Contact("user-a", "alice", "Alice")))
            repository.addLocalContact(Contact("user-c", "charlie", "Charlie"))
            repository.addLocalContact(Contact("user-c", "charlie2", "Charlie B"))
            repository.replaceContacts(listOf(Contact("user-a", "alice", "Alice")))

            assertEquals(listOf("alice"), repository.contacts.first().map { it.accountName })
            repository.addLocalContact(Contact("user-c", "charlie2", "Charlie B"))
            assertEquals("charlie2", repository.search("Charlie B").single().accountName)

            repository.remove("user-a")
            assertEquals(listOf("charlie2"), repository.contacts.first().map { it.accountName })

            repository.clear()
            assertEquals(emptyList<Contact>(), repository.contacts.first())
        }

    @Test
    fun cachedRemoteChatRepository_persistsRemoteSummariesMessagesAndReadState() =
        runTest {
            val local = RoomChatRepository(FakeChatDao())
            val remote = FakeChatRemoteDataSource()
            val repository = CachedRemoteChatRepository(remote, MutableStateFlow(session()), local)

            repository.refreshChats()
            repository.refreshMessages("room-1")
            val sent = repository.sendText("room-1", "ignored", "ignored", "  hello  ")
            repository.markRead("room-1")

            assertEquals("Room 1", repository.chats.first().single().title)
            assertEquals(listOf("m1", sent.id), repository.messages("room-1").first().map { it.id })
            assertEquals("access-token", remote.tokens.distinct().single())
            assertEquals("m2", remote.markedReadMessageId)
            assertEquals(0, repository.chats.first().single().unreadCount)

            repository.clearLocalState()
            assertEquals(emptyList<ChatSummary>(), repository.chats.first())
            assertEquals(emptyList<ChatMessage>(), repository.messages("room-1").first())
        }

    @Test
    fun cachedRemoteChatRepository_marksFailedAndResendsFromRoomCache() =
        runTest {
            val local = RoomChatRepository(FakeChatDao())
            val remote = FakeChatRemoteDataSource()
            val repository = CachedRemoteChatRepository(remote, MutableStateFlow(session()), local)
            remote.failNextSend = true

            val error = runCatching { repository.sendText("room-1", "user-me", "Me", " retry ") }.exceptionOrNull()
            val failed = repository.messages("room-1").first().single()
            val resent = repository.resendMessage(failed.id)

            assertEquals("send failed", error?.message)
            assertEquals(MessageStatus.Failed, failed.status)
            assertEquals("m2", resent?.id)
            assertEquals(listOf("m2"), repository.messages("room-1").first().map { it.id })
        }

    @Test
    fun cachedRemoteContactsRepository_persistsRemoteContactsAndRequests() =
        runTest {
            val local = RoomContactsRepository(FakeContactDao())
            val remote = FakeFriendRemoteDataSource()
            val repository = CachedRemoteContactsRepository(remote, MutableStateFlow(session()), local)

            repository.refreshContacts()
            repository.refreshFriendRequests()
            val results = repository.search("bob")
            repository.sendFriendRequest("user-c", "hi")
            repository.respondFriendRequest("req-1", accept = true)
            val roomId = repository.ensurePrivateChat("user-b")

            assertEquals("Bob", repository.contacts.first().single().displayName)
            assertEquals("Bob", results.single().displayName)
            assertEquals(emptyList<Any>(), repository.incomingRequests.value)
            assertEquals("Cici", repository.outgoingRequests.value.single().counterpartyDisplayName)
            assertEquals("room-private", roomId)
            assertEquals("access-token", remote.tokens.distinct().single())

            repository.clearLocalState()
            assertEquals(emptyList<Contact>(), repository.contacts.first())
            assertEquals(emptyList<Any>(), repository.incomingRequests.value)
            assertEquals(emptyList<Any>(), repository.outgoingRequests.value)
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

    private fun session(): AuthSession =
        AuthSession(
            user = AuthUser(id = "user-me", accountName = "me", displayName = "Me"),
            tokens = TokenPair(accessToken = "access-token", refreshToken = "refresh-token"),
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

    override suspend fun upsertSummaries(summaries: List<ChatSummaryEntity>) {
        summaries.forEach { upsertSummary(it) }
    }

    override suspend fun upsertMessage(message: ChatMessageEntity) {
        val next = (messages.value[message.roomId].orEmpty().filterNot { it.id == message.id } + message)
        messages.value = messages.value + (message.roomId to next)
    }

    override suspend fun upsertMessages(messages: List<ChatMessageEntity>) {
        messages.forEach { upsertMessage(it) }
    }

    override suspend fun findSummary(roomId: String): ChatSummaryEntity? =
        summaries.value.firstOrNull { it.roomId == roomId }

    override suspend fun hasMessage(messageId: String): Boolean =
        messages.value.values.any { roomMessages -> roomMessages.any { it.id == messageId } }

    override suspend fun findMessage(messageId: String): ChatMessageEntity? =
        messages.value.values.flatten().firstOrNull { it.id == messageId }

    override suspend fun updateMessageText(roomId: String, messageId: String, text: String) {
        messages.value =
            messages.value +
            (
                roomId to
                    messages.value[roomId].orEmpty().map {
                        if (it.id == messageId) it.copy(text = text) else it
                    }
            )
    }

    override suspend fun updateMessageStatus(messageId: String, status: String) {
        messages.value =
            messages.value.mapValues { (_, roomMessages) ->
                roomMessages.map { if (it.id == messageId) it.copy(status = status) else it }
            }
    }

    override suspend fun deleteMessage(messageId: String) {
        messages.value =
            messages.value.mapValues { (_, roomMessages) ->
                roomMessages.filterNot { it.id == messageId }
            }
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

    override suspend fun clearMessages(roomId: String) {
        messages.value = messages.value - roomId
    }

    override suspend fun deleteSummary(roomId: String) {
        summaries.value = summaries.value.filterNot { it.roomId == roomId }
    }

    override suspend fun deleteRoom(roomId: String) {
        clearMessages(roomId)
        deleteSummary(roomId)
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

private class FakeChatRemoteDataSource : ChatRemoteDataSource {
    val tokens = mutableListOf<String>()
    var markedReadMessageId = ""
    var failNextSend = false

    override suspend fun fetchChats(token: String): List<BackendChatSummary> {
        tokens += token
        return listOf(
            BackendChatSummary(
                roomId = "room-1",
                name = "Room 1",
                roomType = "group",
                unreadCount = 3,
                lastMessage = BackendChatMessagePreview(id = "m1", content = "seed", createdAt = "2026-07-04T00:00:00Z"),
            ),
        )
    }

    override suspend fun loadMessages(
        roomId: String,
        token: String,
        limit: Int,
        beforeId: String?,
        sinceId: String?,
    ): List<BackendChatMessage> {
        tokens += token
        return listOf(
            BackendChatMessage(
                id = "m1",
                roomId = roomId,
                senderId = "user-a",
                senderUsername = "alice",
                content = "seed",
                createdAt = "2026-07-04T00:00:00Z",
            ),
        )
    }

    override suspend fun sendTextMessage(
        roomId: String,
        content: String,
        token: String,
        quotedMessageId: String?,
    ): BackendChatMessage {
        tokens += token
        if (failNextSend) {
            failNextSend = false
            error("send failed")
        }
        return BackendChatMessage(
            id = "m2",
            roomId = roomId,
            senderId = "user-me",
            senderUsername = "me",
            content = content,
            createdAt = "2026-07-04T00:00:01Z",
        )
    }

    override suspend fun markMessagesRead(roomId: String, messageId: String, token: String) {
        tokens += token
        markedReadMessageId = messageId
    }
}

private class FakeFriendRemoteDataSource : FriendRemoteDataSource {
    val tokens = mutableListOf<String>()

    override suspend fun searchUsers(keyword: String, token: String, limit: Int): List<BackendUser> {
        tokens += token
        return listOf(BackendUser(id = "user-b", username = "bob", nickname = "Bob"))
    }

    override suspend fun fetchFriends(token: String): List<BackendFriendInfo> {
        tokens += token
        return listOf(BackendFriendInfo(user = BackendUser(id = "user-b", username = "bob", nickname = "Bob")))
    }

    override suspend fun sendFriendRequest(targetUserId: String, message: String?, token: String): BackendFriendRequest {
        tokens += token
        return BackendFriendRequest(
            id = "req-out",
            requester = BackendUser(id = "user-me", username = "me"),
            addressee = BackendUser(id = targetUserId, username = "cici", nickname = "Cici"),
            status = "pending",
            message = message,
            isIncoming = false,
        )
    }

    override suspend fun fetchFriendRequests(direction: String?, status: String?, token: String): List<BackendFriendRequest> {
        tokens += token
        return if (direction == "incoming") {
            listOf(
                BackendFriendRequest(
                    id = "req-1",
                    requester = BackendUser(id = "user-a", username = "alice", nickname = "Alice"),
                    addressee = BackendUser(id = "user-me", username = "me"),
                    status = "pending",
                    isIncoming = true,
                ),
            )
        } else {
            emptyList()
        }
    }

    override suspend fun respondFriendRequest(requestId: String, accept: Boolean, token: String): BackendFriendRequest {
        tokens += token
        return BackendFriendRequest(
            id = requestId,
            requester = BackendUser(id = "user-a", username = "alice", nickname = "Alice"),
            addressee = BackendUser(id = "user-me", username = "me"),
            status = if (accept) "accepted" else "declined",
            isIncoming = true,
        )
    }

    override suspend fun ensurePrivateChat(friendUserId: String, token: String): EnsurePrivateChatResponse {
        tokens += token
        return EnsurePrivateChatResponse(roomId = "room-private", roomName = "Bob")
    }
}
