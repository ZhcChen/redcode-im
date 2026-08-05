package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.chat.ChatAPIEndpoint
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.data.chat.RemoteChatRepository
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import com.redcode.im.androidapp.e2ee.E2eeMessageSource
import com.redcode.im.androidapp.e2ee.IncomingChatMessageResolver
import com.redcode.im.androidapp.e2ee.OutgoingTextMessageRouter
import com.redcode.im.androidapp.data.media.FileResourceCache
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.HttpRequest
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.HttpTransport
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RemoteChatRepositoryTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

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
    fun refreshMessagesUsesSharedHistoryResolverBeforePublishingState() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [{
                          "id":"m-secret",
                          "room_id":"room-1",
                          "sender_id":"user-a",
                          "content":"",
                          "encrypted_content":"CQ==",
                          "encryption_metadata":{
                            "protocol":"mls",
                            "version":1,
                            "epoch":1,
                            "sender_device_id":"device-a",
                            "content_type":"application",
                            "control_message_id":"commit-1"
                          },
                          "created_at":"2026-08-05T00:00:00Z"
                        }]
                        """.trimIndent(),
                    ),
                )
            val resolver = RecordingIncomingResolver("decrypted history")
            val repository = repository(transport, incomingResolver = resolver)

            repository.refreshMessages("room-1")

            assertEquals("decrypted history", repository.messages("room-1").first().single().text)
            assertEquals(listOf(E2eeMessageSource.History), resolver.sources)
            assertEquals("CQ==", resolver.messages.single().encryptedContent)
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
    fun e2eeSendUsesCoordinatorIdAndNeverCallsPlaintextMessageApi() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """[{"room_id":"room-1","room_type":"direct","friend_user_id":"user-b"}]""",
                    ),
                    HttpResponse(200, "[]"),
                )
            val outgoing = RecordingOutgoingRouter(messageId = "m-encrypted")
            val incoming = RecordingIncomingResolver("unused")
            val repository = repository(transport, incomingResolver = incoming, outgoingRouter = outgoing)
            repository.refreshChats()

            val sent = repository.sendText("room-1", "user-me", "Me", " secret ")

            assertEquals("m-encrypted", sent.id)
            assertEquals(MessageStatus.Sent, sent.status)
            assertEquals(listOf("room-1:user-b:secret:false"), outgoing.calls)
            assertEquals(listOf("m-encrypted"), incoming.remembered.map { it.id })
            assertEquals(2, transport.requests.size)
            assertTrue(transport.requests.none { it.url.endsWith("/rooms/room-1/messages") && it.method == HTTPMethod.POST })
        }

    @Test
    fun e2eeSendFailureKeepsFailedMessageAndRetryUsesPersistedPending() =
        runTest {
            val transport = QueueTransport(HttpResponse(200, "[]"))
            val outgoing = RecordingOutgoingRouter(messageId = "m-retried", failFirst = true)
            val repository = repository(transport, outgoingRouter = outgoing)

            val failure = runCatching { repository.sendText("room-1", "user-me", "Me", "secret") }.exceptionOrNull()
            val failed = repository.messages("room-1").first().single()
            val resent = repository.resendMessage(failed.id)

            assertEquals("encrypted send failed", failure?.message)
            assertEquals(MessageStatus.Failed, failed.status)
            assertEquals("m-retried", resent?.id)
            assertEquals(listOf("room-1:null:secret:false", "room-1:null:secret:true"), outgoing.calls)
            assertTrue(transport.requests.none { it.method == HTTPMethod.POST })
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
    fun uploadAndSendAttachment_signsUploadsCommitsAndSendsRichMessage() =
        runTest {
            val bytes = "image-bytes".encodeToByteArray()
            val key = "messages/room-1/images_20260705/a.png"
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        {
                          "success":true,
                          "message":"ok",
                          "key":"$key",
                          "signature":{
                            "url":"http://127.0.0.1:19080/mock-bucket/$key",
                            "method":"PUT",
                            "headers":{"X-Mock":"1"}
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "uploaded"),
                    HttpResponse(200, """{"success":true,"message":"committed"}"""),
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-img",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"[图片]",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:02Z",
                            "parts":[
                              {"position":0,"part_type":"image","attachment":{"key":"$key","name":"a.png","mime":"image/png","size":11}}
                            ]
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport)

            val sent =
                repository.uploadAndSendAttachment(
                    roomId = "room-1",
                    senderId = "user-me",
                    senderName = "Me",
                    file =
                        AttachmentUploadPayload(
                            bytes = bytes,
                            fileName = "a.png",
                            mime = "image/png",
                            size = bytes.size.toLong(),
                        ),
                    type = MessagePartType.Image,
                    text = null,
                )

            assertEquals("m-img", sent.id)
            assertEquals("""{"part_type":"image","filename":"a.png","content_type":"image/png","file_size":11}""", transport.requests[0].body)
            assertEquals(HTTPMethod.PUT, transport.requests[1].method)
            assertEquals("http://127.0.0.1:19080/mock-bucket/$key", transport.requests[1].url)
            assertEquals("1", transport.requests[1].headers["X-Mock"])
            assertEquals("image/png", transport.requests[1].headers["Content-Type"])
            assertEquals(bytes.toList(), transport.requests[1].bodyBytes?.toList())
            assertEquals("""{"key":"$key","file_size":11}""", transport.requests[2].body)
            assertEquals(
                """{"parts":[{"type":"image","key":"$key","name":"a.png","mime":"image/png","size":11}]}""",
                transport.requests[3].body,
            )
        }

    @Test
    fun uploadAndSendAttachment_cachesUploadedFileAndKeepsLocalPathOnSentMessage() =
        runTest {
            val bytes = "image-bytes".encodeToByteArray()
            val key = "messages/room-1/images_20260705/a.png"
            val cache = FileResourceCache(temporaryFolder.newFolder("attachment-cache"))
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        {
                          "success":true,
                          "message":"ok",
                          "key":"$key",
                          "signature":{
                            "url":"http://127.0.0.1:19080/mock-bucket/$key",
                            "method":"PUT",
                            "headers":{}
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "uploaded"),
                    HttpResponse(200, """{"success":true,"message":"committed"}"""),
                    HttpResponse(
                        200,
                        """
                        {
                          "message":{
                            "id":"m-img",
                            "room_id":"room-1",
                            "sender_id":"user-me",
                            "sender_nickname":"Me",
                            "content":"[图片]",
                            "status":"sent",
                            "created_at":"2026-07-05T00:00:02Z",
                            "parts":[
                              {"position":0,"part_type":"image","attachment":{"key":"$key","name":"a.png","mime":"image/png","size":11}}
                            ]
                          }
                        }
                        """.trimIndent(),
                    ),
                    HttpResponse(200, "[]"),
                )
            val repository = repository(transport = transport, attachmentFileCache = cache)

            val sent =
                repository.uploadAndSendAttachment(
                    roomId = "room-1",
                    senderId = "user-me",
                    senderName = "Me",
                    file =
                        AttachmentUploadPayload(
                            bytes = bytes,
                            fileName = "a.png",
                            mime = "image/png",
                            size = bytes.size.toLong(),
                        ),
                    type = MessagePartType.Image,
                    text = null,
                )

            val localPath = sent.parts.single().attachment?.localPath
            assertTrue(!localPath.isNullOrBlank())
            assertEquals(bytes.toList(), File(localPath!!).readBytes().toList())
            assertEquals(localPath, repository.messages("room-1").first().single().parts.single().attachment?.localPath)
        }

    @Test
    fun downloadAndCacheAttachment_usesLocalCacheBeforeRequestingDownloadUrlAgain() =
        runTest {
            val bytes = "cached bytes".encodeToByteArray()
            val key = "messages/room-1/files_20260705/a.txt"
            val cache = FileResourceCache(temporaryFolder.newFolder("attachment-cache"))
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        [
                          {
                            "id":"m-file",
                            "room_id":"room-1",
                            "sender_id":"user-a",
                            "content":"[文件]",
                            "created_at":"2026-07-05T00:00:00Z",
                            "parts":[
                              {"position":0,"part_type":"file","attachment":{"key":"$key","name":"a.txt","mime":"text/plain","size":${bytes.size}}}
                            ]
                          }
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(200, """{"success":true,"download_url":"http://127.0.0.1:19080/mock-bucket/$key"}"""),
                    HttpResponse(statusCode = 200, body = "", bodyBytes = bytes),
                )
            val repository = repository(transport = transport, attachmentFileCache = cache)

            repository.refreshMessages("room-1")
            val attachment = repository.messages("room-1").first().single().parts.single().attachment!!
            val first = repository.downloadAndCacheAttachment(roomId = "room-1", attachment = attachment)
            val second = repository.downloadAndCacheAttachment(roomId = "room-1", attachment = first)

            assertEquals(first.localPath, second.localPath)
            assertEquals(bytes.toList(), File(first.localPath!!).readBytes().toList())
            assertEquals(first.localPath, repository.messages("room-1").first().single().parts.single().attachment?.localPath)
            assertEquals(3, transport.requests.size)
            assertEquals("http://10.0.2.2:8010/rooms/room-1/messages/attachments/download?key=messages%2Froom-1%2Ffiles_20260705%2Fa.txt&expires_in_seconds=600", transport.requests[1].url)
            assertEquals("http://127.0.0.1:19080/mock-bucket/$key", transport.requests[2].url)
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

    private fun repository(
        transport: QueueTransport,
        attachmentFileCache: FileResourceCache? = null,
        incomingResolver: IncomingChatMessageResolver? = null,
        outgoingRouter: OutgoingTextMessageRouter? = null,
    ): RemoteChatRepository =
        RemoteChatRepository(
            remoteDataSource = HttpChatRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport)),
            session = MutableStateFlow(session()),
            attachmentFileCache = attachmentFileCache,
            incomingResolver = incomingResolver,
            outgoingRouter = outgoingRouter,
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

    private class RecordingIncomingResolver(private val resolvedText: String) : IncomingChatMessageResolver {
        val messages = mutableListOf<BackendChatMessage>()
        val sources = mutableListOf<E2eeMessageSource>()
        val remembered = mutableListOf<ChatMessage>()

        override suspend fun resolve(
            message: BackendChatMessage,
            source: E2eeMessageSource,
            cachedMessage: ChatMessage?,
        ): ChatMessage {
            messages += message
            sources += source
            return message.toDomain().copy(text = resolvedText)
        }

        override suspend fun rememberResolved(message: ChatMessage) {
            remembered += message
        }
    }

    private class RecordingOutgoingRouter(
        private val messageId: String,
        private val failFirst: Boolean = false,
    ) : OutgoingTextMessageRouter {
        val calls = mutableListOf<String>()

        override suspend fun send(roomId: String, peerUserId: String?, text: String, retry: Boolean): String? {
            calls += "$roomId:$peerUserId:$text:$retry"
            if (failFirst && !retry) error("encrypted send failed")
            return messageId
        }
    }
}
