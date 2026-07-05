package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatMessageQuote
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.MyMuteInfo
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
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
                avatarUrl = "https://asset.example/room.png",
                avatarObjectKey = "room_avatars/room-1/a.png",
                friendUserId = "user-a",
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
                parts =
                    listOf(
                        MessagePart(position = 0, type = MessagePartType.Text, text = "hello"),
                        MessagePart(
                            position = 1,
                            type = MessagePartType.Image,
                            attachment =
                                MessageAttachment(
                                    key = "messages/room-1/images_20260705/a.png",
                                    name = "a.png",
                                    mime = "image/png",
                                    size = 128,
                                    width = 10,
                                    height = 20,
                                    localPath = "/tmp/a.png",
                                ),
                        ),
                    ),
                quotedMessage =
                    ChatMessageQuote(
                        id = "quote-1",
                        roomId = "room-1",
                        senderId = "user-2",
                        senderName = "Bob",
                        text = "quoted",
                        createdAt = Instant.ofEpochMilli(4567),
                    ),
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
                avatarObjectKey = "avatars/user-1/a.png",
            )

        val entity = ContactEntity.fromDomain(contact)
        val mapped = entity.toDomain()

        assertEquals("alice", entity.accountName)
        assertEquals(contact, mapped)
    }

    @Test
    fun roomInfoMemberAndSettings_roundTripDomainFields() {
        val room =
            RoomInfo(
                id = "room-1",
                name = "测试群",
                roomType = "group",
                description = "desc",
                avatarUrl = "https://asset.example/room.png",
                avatarObjectKey = "room_avatars/room-1/a.png",
                ownerId = "user-owner",
                createdAt = Instant.ofEpochMilli(1000),
                updatedAt = Instant.ofEpochMilli(2000),
            )
        val member =
            RoomMember(
                userId = "user-1",
                username = "alice",
                nickname = "Alice",
                avatarUrl = "https://asset.example/a.png",
                avatarObjectKey = "avatars/user-1/a.png",
                role = "admin",
                joinedAt = Instant.ofEpochMilli(3000),
            )
        val settings =
            GroupSettingsSnapshot(
                settings =
                    GroupSettingsInfo(
                        roomId = "room-1",
                        joinApprovalRequired = true,
                        memberCanInvite = false,
                        maxMembers = 200,
                        globalMuteEnabled = true,
                        globalMuteUntil = Instant.ofEpochMilli(4000),
                        globalMuteReason = "quiet",
                        globalMuteSetBy = "user-owner",
                    ),
                myMute =
                    MyMuteInfo(
                        isMuted = true,
                        reason = "test",
                        mutedAt = Instant.ofEpochMilli(5000),
                        muteUntil = Instant.ofEpochMilli(6000),
                    ),
            )

        assertEquals(room, RoomInfoEntity.fromDomain(room).toDomain())
        assertEquals(member, RoomMemberEntity.fromDomain("room-1", member).toDomain())
        assertEquals(settings, GroupSettingsEntity.fromDomain(settings).toDomain())
    }
}
