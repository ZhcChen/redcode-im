package com.redcode.im.androidapp.realtime

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class RealtimeEventProcessorTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun messageEvent_isMappedAndDelegatedToChatCache() =
        runTest {
            val cache = FakeChatCache()
            val processor = processor(cache)

            processor.handle(
                event(
                    """
                    {
                      "type":"message",
                      "message_id":"m-1",
                      "room_id":"room-1",
                      "sender_id":"user-a",
                      "sender_username":"alice",
                      "content":"hello",
                      "timestamp":"2026-07-05T00:00:00Z"
                    }
                    """.trimIndent(),
                ),
            )

            val message = cache.messages.single()
            assertEquals("m-1", message.id)
            assertEquals("room-1", message.roomId)
            assertEquals("alice", message.senderName)
            assertEquals("hello", message.text)
            assertEquals("user-me", cache.currentUserIds.single())
        }

    @Test
    fun messageReadUpdateRoomAndFriendEvents_callExpectedRepositories() =
        runTest {
            val cache = FakeChatCache()
            val contacts = FakeContactsRepository()
            val processor = processor(cache = cache, contacts = contacts)

            processor.handle(event("""{"type":"message_read","room_id":"room-1","reader_id":"user-me"}"""))
            processor.handle(event("""{"type":"message_update","room_id":"room-1","message_id":"m-1","is_deleted":true}"""))
            processor.handle(
                event(
                    """{"type":"pin_update","room_id":"room-1","message_id":"m-1","is_pinned":true,"pinned_at":"2026-07-05T00:00:00Z","pinned_by":"user-me"}""",
                ),
            )
            processor.handle(
                event(
                    """{"type":"reaction_update","room_id":"room-1","message_id":"m-1","reaction_key":"👍","user_id":"user-me","action":"add"}""",
                ),
            )
            processor.handle(event("""{"type":"room_updated","room_id":"room-1"}"""))
            processor.handle(event("""{"type":"room_history_cleared","room_id":"room-1"}"""))
            processor.handle(event("""{"type":"friend_request_update","pending_count":3}"""))

            assertEquals(listOf("room-1"), cache.markReadRooms)
            assertEquals(listOf("room-1:m-1"), cache.deletedMessages)
            assertEquals(listOf("room-1:m-1:true:user-me"), cache.pinUpdates)
            assertEquals(listOf("room-1:m-1:👍:user-me:true:user-me"), cache.reactionUpdates)
            assertEquals(1, cache.refreshCount)
            assertEquals(listOf("room-1"), cache.removedRooms)
            assertEquals(1, contacts.refreshFriendRequestsCount)
        }

    @Test
    fun messageReadForOtherUserAndInvalidPayloads_areIgnored() =
        runTest {
            val cache = FakeChatCache()
            val processor = processor(cache)

            processor.handle(event("""{"type":"message_read","room_id":"room-1","reader_id":"user-other"}"""))
            processor.handle(event("""{"type":"message","room_id":"room-1"}"""))
            processor.handle(event("""{"type":"message_update","room_id":"room-1","message_id":"m-1","is_deleted":false}"""))

            assertEquals(emptyList<String>(), cache.markReadRooms)
            assertEquals(emptyList<ChatMessage>(), cache.messages)
            assertEquals(emptyList<String>(), cache.deletedMessages)
        }

    @Test
    fun repositoryFailures_areCapturedWithoutThrowing() =
        runTest {
            val processor = processor(FakeChatCache(shouldFail = true))

            processor.handle(event("""{"type":"room_created","room_id":"room-1"}"""))

            assertNotNull(processor.lastError)
        }

    private fun processor(
        cache: FakeChatCache,
        contacts: FakeContactsRepository = FakeContactsRepository(),
    ): RealtimeEventProcessor =
        RealtimeEventProcessor(
            chatCache = cache,
            contactsRepository = contacts,
            currentUserIdProvider = { "user-me" },
        )

    private fun event(raw: String): WebSocketServerEvent {
        val payload = json.parseToJsonElement(raw) as JsonObject
        return WebSocketServerEvent(type = payload["type"]!!.jsonPrimitive.content, payload = payload)
    }
}

private class FakeChatCache(
    private val shouldFail: Boolean = false,
) : RealtimeChatCache {
    val messages = mutableListOf<ChatMessage>()
    val currentUserIds = mutableListOf<String?>()
    val markReadRooms = mutableListOf<String>()
    val deletedMessages = mutableListOf<String>()
    val pinUpdates = mutableListOf<String>()
    val reactionUpdates = mutableListOf<String>()
    val removedRooms = mutableListOf<String>()
    var refreshCount = 0

    override suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?) {
        messages += message
        currentUserIds += currentUserId
    }

    override suspend fun markRead(roomId: String) {
        markReadRooms += roomId
    }

    override suspend fun markMessageDeleted(roomId: String, messageId: String) {
        deletedMessages += "$roomId:$messageId"
    }

    override suspend fun updateMessagePin(roomId: String, messageId: String, pinned: Boolean, pinnedAt: java.time.Instant?, pinnedBy: String?) {
        pinUpdates += "$roomId:$messageId:$pinned:$pinnedBy"
    }

    override suspend fun applyReactionUpdate(
        roomId: String,
        messageId: String,
        reactionKey: String,
        userId: String,
        added: Boolean,
        currentUserId: String?,
    ) {
        reactionUpdates += "$roomId:$messageId:$reactionKey:$userId:$added:$currentUserId"
    }

    override suspend fun removeRoom(roomId: String) {
        removedRooms += roomId
    }

    override suspend fun refreshChats() {
        if (shouldFail) error("refresh failed")
        refreshCount += 1
    }
}

private class FakeContactsRepository : ContactsRepository {
    var refreshFriendRequestsCount = 0

    override val contacts: Flow<List<Contact>> = flowOf(emptyList())

    override suspend fun refreshFriendRequests() {
        refreshFriendRequestsCount += 1
    }

    override suspend fun search(query: String): List<Contact> = emptyList()

    override suspend fun addLocalContact(contact: Contact) = Unit
}
