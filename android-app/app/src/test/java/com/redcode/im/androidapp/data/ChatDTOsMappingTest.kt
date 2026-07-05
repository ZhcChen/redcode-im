package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import com.redcode.im.androidapp.data.chat.BackendChatMessagePreview
import com.redcode.im.androidapp.data.chat.BackendChatSummary
import org.junit.Assert.assertEquals
import org.junit.Test

class ChatDTOsMappingTest {
    @Test
    fun summary_prefersPrivateFriendNamesAndDefaultsInvalidDates() {
        val summary =
            BackendChatSummary(
                roomId = "room-direct",
                name = "fallback",
                roomType = "private",
                friendUsername = "alice",
                friendNickname = "Alice",
                friendRemark = "A 备注",
                lastMessage = BackendChatMessagePreview(id = "m-1", content = "hello", createdAt = "not-a-date"),
            ).toDomain()

        assertEquals("A 备注", summary.title)
        assertEquals(ChatRoomType.Direct, summary.roomType)
        assertEquals("hello", summary.lastMessagePreview)
        assertEquals(java.time.Instant.EPOCH, summary.updatedAt)
    }

    @Test
    fun summary_mapsPublicAsGroupAndUsesGroupFallbackTitle() {
        val summary =
            BackendChatSummary(
                roomId = "room-group",
                roomType = "public",
                lastMessage = BackendChatMessagePreview(id = "m-1", createdAt = "2026-07-05T00:00:00Z"),
            ).toDomain()

        assertEquals("群聊", summary.title)
        assertEquals(ChatRoomType.Group, summary.roomType)
        assertEquals(java.time.Instant.parse("2026-07-05T00:00:00Z"), summary.updatedAt)
    }

    @Test
    fun message_mapsSenderFallbackStatusAndDeletedText() {
        val pending =
            BackendChatMessage(
                id = "m-1",
                roomId = "room-1",
                senderId = "user-a",
                senderUsername = "alice",
                content = "sending",
                status = "sending",
                createdAt = "",
            ).toDomain()
        val failedDeleted =
            BackendChatMessage(
                id = "m-2",
                roomId = "room-1",
                senderId = "user-b",
                content = "deleted",
                status = "failed",
                isDeleted = true,
            ).toDomain()

        assertEquals("alice", pending.senderName)
        assertEquals(MessageStatus.Pending, pending.status)
        assertEquals(java.time.Instant.EPOCH, pending.createdAt)
        assertEquals("user-b", failedDeleted.senderName)
        assertEquals(MessageStatus.Failed, failedDeleted.status)
        assertEquals("消息已删除", failedDeleted.text)
    }
}
