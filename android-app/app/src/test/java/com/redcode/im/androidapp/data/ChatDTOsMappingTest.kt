package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import com.redcode.im.androidapp.data.chat.BackendChatMessagePreview
import com.redcode.im.androidapp.data.chat.BackendChatSummary
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

class ChatDTOsMappingTest {
    private val json = Json { ignoreUnknownKeys = true }

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
                isPinned = true,
                pinnedAt = "2026-07-05T00:00:01Z",
                pinnedBy = "user-a",
                quotedMessage =
                    com.redcode.im.androidapp.data.chat.BackendQuotedMessage(
                        id = "q-1",
                        roomId = "room-1",
                        senderId = "user-q",
                        senderUsername = "quote-user",
                        content = "quote",
                        createdAt = "2026-07-05T00:00:00Z",
                    ),
            ).toDomain()

        assertEquals("alice", pending.senderName)
        assertEquals(MessageStatus.Pending, pending.status)
        assertEquals(java.time.Instant.EPOCH, pending.createdAt)
        assertEquals("user-b", failedDeleted.senderName)
        assertEquals(MessageStatus.Failed, failedDeleted.status)
        assertEquals("消息已删除", failedDeleted.text)
        assertEquals(true, failedDeleted.isDeleted)
        assertEquals(true, failedDeleted.isPinned)
        assertEquals("user-a", failedDeleted.pinnedBy)
        assertEquals(java.time.Instant.parse("2026-07-05T00:00:01Z"), failedDeleted.pinnedAt)
        assertEquals("q-1", failedDeleted.quotedMessage?.id)
        assertEquals("quote-user", failedDeleted.quotedMessage?.senderName)
    }

    @Test
    fun message_mapsAttachmentParts() {
        val payload =
            """
            {
              "id":"m-attach",
              "room_id":"room-1",
              "sender_id":"user-a",
              "content":"[图片]",
              "parts":[
                {"position":0,"part_type":"text","text":"look"},
                {"position":1,"part_type":"image","attachment":{"key":"messages/room-1/images_20260705/a.png","name":"a.png","mime":"image/png","size":128,"width":10,"height":20}}
              ]
            }
            """.trimIndent()

        val message = json.decodeFromString<BackendChatMessage>(payload).toDomain()

        assertEquals(2, message.parts.size)
        assertEquals(MessagePartType.Text, message.parts[0].type)
        assertEquals("look", message.parts[0].text)
        assertEquals(MessagePartType.Image, message.parts[1].type)
        assertEquals("a.png", message.parts[1].attachment?.displayName)
        assertEquals(128L, message.parts[1].attachment?.size)
    }
}
