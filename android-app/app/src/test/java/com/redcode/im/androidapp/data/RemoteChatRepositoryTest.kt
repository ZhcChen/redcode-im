package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.chat.ChatAPIEndpoint
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.data.chat.RemoteChatRepository
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.HttpRequest
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.HttpTransport
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteChatRepositoryTest {
    @Test
    fun chatEndpoint_buildsMessageQueryWithBoundsAndEncoding() {
        val endpoint = ChatAPIEndpoint.messages(roomId = "room-1", limit = 500, beforeId = "m 1")

        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/messages?limit=200&before_id=m+1",
            endpoint.url(RedCodeEnvironment.localEmulator()),
        )
    }

    @Test
    fun chatEndpoint_buildsMessageActionPaths() {
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/pin",
            ChatAPIEndpoint.pinRoom("room-1", pinned = true).url(RedCodeEnvironment.localEmulator()),
        )
        assertEquals(HTTPMethod.POST, ChatAPIEndpoint.pinRoom("room-1", pinned = true).method)
        assertEquals(HTTPMethod.DELETE, ChatAPIEndpoint.pinRoom("room-1", pinned = false).method)
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/notification-settings",
            ChatAPIEndpoint.updateNotificationSettings("room-1").url(RedCodeEnvironment.localEmulator()),
        )
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/messages/m-1",
            ChatAPIEndpoint.deleteMessage("room-1", "m-1").url(RedCodeEnvironment.localEmulator()),
        )
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/messages/m-1/reactions?reaction_key=%F0%9F%91%8D",
            ChatAPIEndpoint.removeReaction("room-1", "m-1", "👍").url(RedCodeEnvironment.localEmulator()),
        )
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/messages/attachments/download?key=messages%2Froom-1%2Fimages_20260705%2Fa.png&expires_in_seconds=600",
            ChatAPIEndpoint.attachmentDownload("room-1", "messages/room-1/images_20260705/a.png").url(RedCodeEnvironment.localEmulator()),
        )
    }

    @Test
    fun refreshChats_loadsRemoteSummariesWithBearerToken() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "room_id":"room-1",
                            "name":"群聊",
                            "room_type":"group",
                            "unread_count":2,
                            "is_pinned":true,
                            "is_muted":false,
                            "last_message":{
                              "id":"m-1",
                              "content":"hello",
                              "created_at":"2026-07-05T00:00:00Z"
                            }
                          }
                        ]
                        """.trimIndent(),
                    ),
                )
            val repository = repository(transport)

            repository.refreshChats()

            val summary = repository.chats.first().single()
            assertEquals("room-1", summary.roomId)
            assertEquals("群聊", summary.title)
            assertEquals(ChatRoomType.Group, summary.roomType)
            assertEquals("hello", summary.lastMessagePreview)
            assertEquals(2, summary.unreadCount)
            assertEquals("Bearer access-token", transport.requests.single().headers["Authorization"])
        }

    @Test
    fun refreshMessagesAndSendText_updateRemoteMessageState() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-1",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "sender_username":"alice",
                            "content":"old",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:00Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-2",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"new",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:01Z"
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1", limit = 20)
            val sent = repository.sendText("room-1", "ignored", "ignored", "  new  ")

            assertEquals("new", sent.text)
            assertEquals(listOf("old", "new"), repository.messages("room-1").first().map { it.text })
            assertEquals(
                "http://10.0.2.2:8010/rooms/room-1/messages?limit=20",
                transport.requests[0].url,
            )
            assertEquals(HTTPMethod.POST, transport.requests[1].method)
            assertEquals("""{"content":"new"}""", transport.requests[1].body)
        }

    @Test
    fun sendText_withQuotedMessagePassesQuotedMessageId() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-1",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "sender_username":"alice",
                            "content":"old",
                            "created_at":"2026-07-05T00:00:00Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-2",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "content":"reply",
                            "created_at":"2026-07-05T00:00:01Z",
                            "quoted_message":{
                              "id":"m-1",
                              "room_id":"room-1",
                              "sender_id":"user-a",
                              "sender_username":"alice",
                              "content":"old",
                              "created_at":"2026-07-05T00:00:00Z"
                            }
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1")
            val sent = repository.sendText("room-1", "user-me", "Me", " reply ", quotedMessageId = "m-1")

            assertEquals("m-1", sent.quotedMessage?.id)
            assertEquals("""{"content":"reply","quoted_message_id":"m-1"}""", transport.requests[1].body)
        }

    @Test
    fun sendAttachmentReference_postsRichMessageParts() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-img",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"caption [图片]",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:02Z",
                            "parts":[
                              {"position":0,"part_type":"text","text":"caption"},
                              {"position":1,"part_type":"image","attachment":{"key":"messages/room-1/images_20260705/a.png","name":"a.png","mime":"image/png","size":128,"width":10,"height":20}}
                            ]
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            val sent =
                repository.sendAttachmentReference(
                    roomId = "room-1",
                    senderId = "user-me",
                    senderName = "Me",
                    text = " caption ",
                    parts =
                        listOf(
                            MessagePart(
                                position = 0,
                                type = MessagePartType.Image,
                                attachment =
                                    MessageAttachment(
                                        key = "messages/room-1/images_20260705/a.png",
                                        name = "a.png",
                                        mime = "image/png",
                                        size = 128,
                                        width = 10,
                                        height = 20,
                                    ),
                            ),
                        ),
                )

            assertEquals("m-img", sent.id)
            assertEquals(MessagePartType.Image, sent.parts[1].type)
            assertEquals(
                """{"content":"caption","parts":[{"type":"image","key":"messages/room-1/images_20260705/a.png","name":"a.png","mime":"image/png","size":128,"width":10,"height":20}]}""",
                transport.requests[0].body,
            )
        }

    @Test
    fun sendAttachmentReference_withoutCaptionDoesNotSendPreviewAsContent() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-file",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"[文件]",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:02Z",
                            "parts":[
                              {"position":0,"part_type":"file","attachment":{"key":"messages/room-1/files_20260705/a.pdf","name":"a.pdf","mime":"application/pdf","size":128}}
                            ]
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            repository.sendAttachmentReference(
                roomId = "room-1",
                senderId = "user-me",
                senderName = "Me",
                text = null,
                parts =
                    listOf(
                        MessagePart(
                            position = 0,
                            type = MessagePartType.File,
                            attachment =
                                MessageAttachment(
                                    key = "messages/room-1/files_20260705/a.pdf",
                                    name = "a.pdf",
                                    mime = "application/pdf",
                                    size = 128,
                                ),
                        ),
                    ),
            )

            assertEquals(
                """{"parts":[{"type":"file","key":"messages/room-1/files_20260705/a.pdf","name":"a.pdf","mime":"application/pdf","size":128}]}""",
                transport.requests[0].body,
            )
        }

    @Test
    fun loadOlderMessages_usesFirstMessageAsBeforeCursorAndMergesResults() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-2",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "content":"newer",
                            "created_at":"2026-07-05T00:00:02Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-1",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "content":"older",
                            "created_at":"2026-07-05T00:00:01Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1")
            val loaded = repository.loadOlderMessages("room-1")

            assertEquals(true, loaded)
            assertEquals(listOf("m-1", "m-2"), repository.messages("room-1").first().map { it.id })
            assertEquals(
                "http://10.0.2.2:8010/rooms/room-1/messages?limit=50&before_id=m-2",
                transport.requests[1].url,
            )
        }

    @Test
    fun loadOlderMessages_returnsFalseWhenOlderPageContainsOnlyCachedDuplicates() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-2",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "content":"newer",
                            "created_at":"2026-07-05T00:00:02Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-2",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "content":"newer",
                            "created_at":"2026-07-05T00:00:02Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1")
            val loaded = repository.loadOlderMessages("room-1")

            assertEquals(false, loaded)
            assertEquals(listOf("m-2"), repository.messages("room-1").first().map { it.id })
        }

    @Test
    fun searchMessages_usesCachedMessagesWithoutNetworkRequest() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-1",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "sender_username":"alice",
                            "content":"hello search",
                            "created_at":"2026-07-05T00:00:00Z"
                          }
                        ]
                        """.trimIndent(),
                    ),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1")
            val results = repository.searchMessages("room-1", "search")

            assertEquals(listOf("m-1"), results.map { it.id })
            assertEquals(1, transport.requests.size)
        }

    @Test
    fun markRead_callsBackendAndClearsUnreadCount() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(200, """[{"room_id":"room-1","name":"私聊","room_type":"private","unread_count":1}]"""),
                    HttpResponse(
                        200,
                        """[{"id":"m-1","room_id":"room-1","sender_id":"user-a","content":"old","created_at":"2026-07-05T00:00:00Z"}]""",
                    ),
                    HttpResponse(200, """{"success":true}"""),
                )
            val repository = repository(transport)

            repository.refreshChats()
            repository.refreshMessages("room-1")
            repository.markRead("room-1")

            assertEquals(0, repository.chats.first().single().unreadCount)
            assertEquals("http://10.0.2.2:8010/rooms/room-1/messages/read", transport.requests.last().url)
            assertEquals("""{"message_id":"m-1"}""", transport.requests.last().body)
        }

    @Test
    fun chatSummaryActions_callBackendAndUpdateLocalSummaryOrdering() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "room_id":"room-a",
                            "name":"A",
                            "room_type":"group",
                            "unread_count":0,
                            "is_pinned":false,
                            "is_muted":false,
                            "last_message":{"id":"m-a","content":"a","created_at":"2026-07-05T00:00:01Z"}
                          },
                          {
                            "room_id":"room-b",
                            "name":"B",
                            "room_type":"group",
                            "unread_count":0,
                            "is_pinned":false,
                            "is_muted":false,
                            "last_message":{"id":"m-b","content":"b","created_at":"2026-07-05T00:00:02Z"}
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(200, """{"success":true,"is_pinned":true}"""),
                    HttpResponse(200, """{"notification_settings":2}"""),
                )
            val repository = repository(transport)

            repository.refreshChats()
            repository.setChatPinned("room-a", pinned = true)
            repository.setChatMuted("room-a", muted = true)

            val summaries = repository.chats.first()
            assertEquals(listOf("room-a", "room-b"), summaries.map { it.roomId })
            assertEquals(true, summaries.first().isPinned)
            assertEquals(true, summaries.first().isMuted)
            assertEquals(HTTPMethod.POST, transport.requests[1].method)
            assertEquals("http://10.0.2.2:8010/rooms/room-a/pin", transport.requests[1].url)
            assertEquals(HTTPMethod.POST, transport.requests[2].method)
            assertEquals("http://10.0.2.2:8010/rooms/room-a/notification-settings", transport.requests[2].url)
            assertEquals("""{"notification_settings":2}""", transport.requests[2].body)
        }

    @Test
    fun messageActions_callBackendAndUpdateLocalMessages() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """[{"id":"m-1","room_id":"room-1","sender_id":"user-me","content":"seed","created_at":"2026-07-05T00:00:00Z"}]""",
                    ),
                    HttpResponse(
                        200,
                        """{"id":"m-1","room_id":"room-1","sender_id":"user-me","content":"","is_deleted":true,"created_at":"2026-07-05T00:00:00Z"}""",
                    ),
                    HttpResponse(200, "[]"),
                    HttpResponse(
                        200,
                        """
                        {
                          "room_id":"room-1",
                          "is_pinned":true,
                          "pinned_at":"2026-07-05T00:00:02Z",
                          "pinned_by":"user-me",
                          "message":{
                            "id":"m-1",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "content":"seed",
                            "is_pinned":true,
                            "pinned_at":"2026-07-05T00:00:02Z",
                            "pinned_by":"user-me",
                            "created_at":"2026-07-05T00:00:00Z"
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """{"success":true,"message":"反应已添加","summaries":[{"reaction_key":"👍","count":2,"has_self":true}]}""",
                    ),
                    HttpResponse(
                        200,
                        """{"success":true,"message":"反应已删除","summaries":[]}""",
                    ),
                )
            val repository = repository(transport)

            repository.refreshMessages("room-1")
            val deleted = repository.deleteMessage("room-1", "m-1")
            val pinned = repository.setMessagePinned("room-1", "m-1", pinned = true)
            val reactions = repository.setReaction("room-1", "m-1", "👍", selected = true)
            val emptyReactions = repository.setReaction("room-1", "m-1", "👍", selected = false)

            val message = repository.messages("room-1").first().single()
            assertEquals(true, deleted?.isDeleted)
            assertEquals(true, pinned?.isPinned)
            assertEquals("user-me", pinned?.pinnedBy)
            assertEquals(2L, reactions.single().count)
            assertEquals(0, emptyReactions.size)
            assertEquals(emptyList<Any>(), message.reactions)
            assertEquals(HTTPMethod.DELETE, transport.requests[1].method)
            assertEquals("http://10.0.2.2:8010/rooms/room-1/messages/m-1", transport.requests[1].url)
            assertEquals(HTTPMethod.POST, transport.requests[4].method)
            assertEquals("http://10.0.2.2:8010/rooms/room-1/messages/m-1/reactions", transport.requests[4].url)
            assertEquals("""{"reaction_key":"👍"}""", transport.requests[4].body)
            assertEquals(HTTPMethod.DELETE, transport.requests[5].method)
            assertEquals(
                "http://10.0.2.2:8010/rooms/room-1/messages/m-1/reactions?reaction_key=%F0%9F%91%8D",
                transport.requests[5].url,
            )
        }

    @Test
    fun failedSend_isKeptForResendAndResendReplacesLocalMessage() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(500, """{"message":"network down"}"""),
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-retry",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"retry me",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:02Z"
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            val error = runCatching { repository.sendText("room-1", "user-me", "Me", " retry me ") }.exceptionOrNull()
            val failed = repository.messages("room-1").first().single()
            val resent = repository.resendMessage(failed.id)

            assertEquals("network down", error?.message)
            assertEquals(MessageStatus.Failed, failed.status)
            assertEquals("m-retry", resent?.id)
            assertEquals(listOf("m-retry"), repository.messages("room-1").first().map { it.id })
            assertEquals(MessageStatus.Sent, repository.messages("room-1").first().single().status)
        }

    @Test
    fun missingToken_rejectsRemoteOperations() =
        runTest {
            val repository =
                RemoteChatRepository(
                    remoteDataSource = HttpChatRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), QueueTransport())),
                    session = MutableStateFlow(null),
                )

            assertTrue(runCatching { repository.refreshChats() }.exceptionOrNull() is IllegalStateException)
        }

    private fun repository(transport: QueueTransport): RemoteChatRepository =
        RemoteChatRepository(
            remoteDataSource = HttpChatRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport)),
            session = MutableStateFlow(session()),
        )

    private fun session(): AuthSession =
        AuthSession(
            user = AuthUser(id = "user-me", accountName = "me", displayName = "Me"),
            tokens = TokenPair(accessToken = "access-token", refreshToken = "refresh-token"),
        )

    private class QueueTransport(
        vararg responses: HttpResponse,
    ) : HttpTransport {
        private val responses = ArrayDeque(responses.toList())
        val requests = mutableListOf<HttpRequest>()

        override suspend fun execute(request: HttpRequest): HttpResponse {
            requests += request
            return responses.removeFirst()
        }
    }
}
