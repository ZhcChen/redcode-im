package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class RoomEntityMappingTest {
    @Test
    fun chatSummary_roundTripsDomainFields() {
        val summary =
            ChatSummary(
                roomId = "room-1",
                title = "测试群",
                roomType = ChatRoomType.Group,
                lastMessagePreview = "hello",
                unreadCount = 3,
                isPinned = true,
                isMuted = true,
                updatedAt = Instant.ofEpochMilli(1234),
            )

        val entity = ChatSummaryEntity.fromDomain(summary)
        val mapped = entity.toDomain()

        assertEquals("Group", entity.roomType)
        assertEquals(summary, mapped)
    }

    @Test
    fun chatMessage_roundTripsDomainFields() {
        val message =
            ChatMessage(
                id = "message-1",
                roomId = "room-1",
                senderId = "user-1",
                senderName = "Alice",
                text = "hello",
                status = MessageStatus.Pending,
                createdAt = Instant.ofEpochMilli(5678),
                isDeleted = true,
                isPinned = true,
                pinnedAt = Instant.ofEpochMilli(6789),
                pinnedBy = "user-2",
                reactions = listOf(MessageReactionSummary(reactionKey = "👍", count = 2, hasSelf = true)),
            )

        val entity = ChatMessageEntity.fromDomain(message)
        val mapped = entity.toDomain()

        assertEquals("Pending", entity.status)
        assertEquals(message, mapped)
    }

    @Test
    fun contact_roundTripsDomainFields() {
        val contact =
            Contact(
                userId = "user-1",
                accountName = "alice",
                displayName = "Alice",
                avatarUrl = "https://asset.example/alice.png",
            )

        val entity = ContactEntity.fromDomain(contact)
        val mapped = entity.toDomain()

        assertEquals("alice", entity.accountName)
        assertEquals(contact, mapped)
    }
}
