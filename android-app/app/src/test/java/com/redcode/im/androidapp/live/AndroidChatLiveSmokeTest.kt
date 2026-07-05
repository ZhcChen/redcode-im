package com.redcode.im.androidapp.live

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class AndroidChatLiveSmokeTest {
    @Test
    fun androidClientAndH5CompatibleHttpCanReadEachOtherMessages() =
        runTest {
            assumeTrue(
                "Set RED_CODE_ANDROID_LIVE_CHAT_SMOKE=1 when the local Compose API is running",
                liveSmokeEnabled(),
            )

            val apiClient = APIClient(liveEnvironment())
            val authDataSource = HttpAuthRemoteDataSource(apiClient)
            val chatDataSource = HttpChatRemoteDataSource(apiClient)
            val suffix = randomSuffix()
            val h5Session = registerAndLogin(authDataSource, "h5and$suffix")
            val androidSession = registerAndLogin(authDataSource, "andh5$suffix")
            val room =
                apiClient
                    .post<CreateGroupRoomRequest, CreateRoomResponse>(
                        createRoomEndpoint,
                        CreateGroupRoomRequest(
                            name = "android h5 interop $suffix",
                            description = "live smoke",
                            memberIds = listOf(androidSession.user.id),
                        ),
                        bearerToken = h5Session.tokens.accessToken,
                    )
                    .room
            val h5Text = "hello from h5 $suffix"
            val androidText = "hello from android $suffix"
            val imageName = "android-smoke-$suffix.png"
            val imageKey = "messages/${room.id}/images_20260705/$imageName"

            val h5Message =
                chatDataSource.sendTextMessage(
                    room.id,
                    h5Text,
                    h5Session.tokens.accessToken,
                    quotedMessageId = null,
                )
            val androidMessage =
                chatDataSource.sendTextMessage(
                    room.id,
                    androidText,
                    androidSession.tokens.accessToken,
                    quotedMessageId = null,
                )
            val androidImageMessage =
                chatDataSource.sendRichMessage(
                    room.id,
                    content = "android image $suffix",
                    parts =
                        listOf(
                            MessagePart(
                                position = 0,
                                type = MessagePartType.Image,
                                attachment =
                                    MessageAttachment(
                                        key = imageKey,
                                        name = imageName,
                                        mime = "image/png",
                                        size = 128,
                                        width = 16,
                                        height = 16,
                                    ),
                            ),
                        ),
                    token = androidSession.tokens.accessToken,
                    quotedMessageId = null,
                )
            val h5Visible = chatDataSource.loadMessages(room.id, h5Session.tokens.accessToken, limit = 20)
            val androidVisible = chatDataSource.loadMessages(room.id, androidSession.tokens.accessToken, limit = 20)

            assertEquals("group", room.roomType)
            assertEquals(h5Text, h5Message.content)
            assertEquals(androidText, androidMessage.content)
            assertTrue(
                androidImageMessage.parts.any {
                    it.partType == "image" && it.attachment?.key == imageKey
                },
            )
            assertTrue(h5Visible.any { it.id == h5Message.id && it.content == h5Text })
            assertTrue(h5Visible.any { it.id == androidMessage.id && it.content == androidText })
            assertTrue(
                h5Visible.any { message ->
                    message.id == androidImageMessage.id && message.parts.any { it.attachment?.name == imageName }
                },
            )
            assertTrue(androidVisible.any { it.id == h5Message.id && it.content == h5Text })
            assertTrue(androidVisible.any { it.id == androidMessage.id && it.content == androidText })
            assertTrue(
                androidVisible.any { message ->
                    message.id == androidImageMessage.id && message.parts.any { it.attachment?.mime == "image/png" }
                },
            )

            chatDataSource.markMessagesRead(room.id, androidMessage.id, h5Session.tokens.accessToken)
            chatDataSource.markMessagesRead(room.id, h5Message.id, androidSession.tokens.accessToken)
        }

    private suspend fun registerAndLogin(authDataSource: HttpAuthRemoteDataSource, username: String): AuthSession {
        val password = "secret123"
        authDataSource.register(username = username, password = password, nickname = username)
        return authDataSource.login(username = username, password = password).toDomain()
    }

    private fun liveSmokeEnabled(): Boolean =
        System.getenv("RED_CODE_ANDROID_LIVE_SMOKE") == "1" ||
            System.getenv("RED_CODE_ANDROID_LIVE_CHAT_SMOKE") == "1"

    private fun liveEnvironment(): RedCodeEnvironment =
        RedCodeEnvironment(
            apiBaseUrl = System.getenv("ANDROID_APP_LIVE_API_BASE_URL") ?: "http://127.0.0.1:8010",
            wsUrl = System.getenv("ANDROID_APP_LIVE_WS_URL") ?: "ws://127.0.0.1:8010/ws",
        )

    private fun randomSuffix(): String =
        System.nanoTime().toString(16).takeLast(8)

    @Serializable
    private data class CreateGroupRoomRequest(
        val name: String,
        val description: String? = null,
        @SerialName("room_type")
        val roomType: String = "group",
        @SerialName("member_ids")
        val memberIds: List<String>,
    )

    @Serializable
    private data class CreateRoomResponse(
        val room: LiveRoomInfo,
    )

    @Serializable
    private data class LiveRoomInfo(
        val id: String,
        val name: String,
        @SerialName("room_type")
        val roomType: String,
    )

    private companion object {
        val createRoomEndpoint = APIEndpoint(HTTPMethod.POST, "/rooms")
    }
}
