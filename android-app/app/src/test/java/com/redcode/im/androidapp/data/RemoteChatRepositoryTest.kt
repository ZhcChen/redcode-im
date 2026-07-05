package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.ChatRoomType
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
