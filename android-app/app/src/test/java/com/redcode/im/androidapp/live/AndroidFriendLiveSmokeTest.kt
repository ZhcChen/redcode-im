package com.redcode.im.androidapp.live

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.data.contacts.HttpFriendRemoteDataSource
import com.redcode.im.androidapp.data.contacts.RemoteContactsRepository
import com.redcode.im.androidapp.network.APIClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class AndroidFriendLiveSmokeTest {
    @Test
    fun androidClientAndH5CompatibleHttpCanCompleteFriendPrivateChatFlow() =
        runTest {
            assumeTrue(
                "Set RED_CODE_ANDROID_LIVE_SMOKE=1 when the local Compose API is running",
                liveSmokeEnabled(),
            )

            val apiClient = APIClient(liveEnvironment())
            val authDataSource = HttpAuthRemoteDataSource(apiClient)
            val friendDataSource = HttpFriendRemoteDataSource(apiClient)
            val chatDataSource = HttpChatRemoteDataSource(apiClient)
            val suffix = randomSuffix()
            val h5Session = registerAndLogin(authDataSource, "h5fr$suffix")
            val androidSession = registerAndLogin(authDataSource, "andfr$suffix")
            val h5Contacts = RemoteContactsRepository(friendDataSource, MutableStateFlow(h5Session))
            val androidContacts = RemoteContactsRepository(friendDataSource, MutableStateFlow(androidSession))

            val searchResults = h5Contacts.search(androidSession.user.accountName)
            val androidUser = searchResults.single { it.userId == androidSession.user.id }
            h5Contacts.sendFriendRequest(androidUser.userId, message = "android friend smoke")
            androidContacts.refreshFriendRequests()
            val incomingRequest =
                androidContacts.incomingRequests.value.single {
                    it.counterpartyUserId == h5Session.user.id
                }
            androidContacts.respondFriendRequest(incomingRequest.id, accept = true)
            h5Contacts.refreshContacts()
            androidContacts.refreshContacts()
            val roomId = androidContacts.ensurePrivateChat(h5Session.user.id)
            val text = "hello from android friend $suffix"
            val sent =
                chatDataSource.sendTextMessage(
                    roomId,
                    text,
                    androidSession.tokens.accessToken,
                    quotedMessageId = null,
                )
            val h5Visible = chatDataSource.loadMessages(roomId, h5Session.tokens.accessToken, limit = 20)

            assertTrue(h5Contacts.contacts.first().any { it.userId == androidSession.user.id })
            assertTrue(androidContacts.contacts.first().any { it.userId == h5Session.user.id })
            assertEquals(text, sent.content)
            assertTrue(h5Visible.any { it.id == sent.id && it.content == text })
            chatDataSource.markMessagesRead(roomId, sent.id, h5Session.tokens.accessToken)
        }

    private suspend fun registerAndLogin(authDataSource: HttpAuthRemoteDataSource, username: String): AuthSession {
        val password = "secret123"
        authDataSource.register(username = username, password = password, nickname = username)
        return authDataSource.login(username = username, password = password).toDomain()
    }

    private fun liveSmokeEnabled(): Boolean =
        System.getenv("RED_CODE_ANDROID_LIVE_SMOKE") == "1" ||
            System.getenv("RED_CODE_ANDROID_LIVE_FRIEND_SMOKE") == "1"

    private fun liveEnvironment(): RedCodeEnvironment =
        RedCodeEnvironment(
            apiBaseUrl = System.getenv("ANDROID_APP_LIVE_API_BASE_URL") ?: "http://127.0.0.1:8010",
            wsUrl = System.getenv("ANDROID_APP_LIVE_WS_URL") ?: "ws://127.0.0.1:8010/ws",
        )

    private fun randomSuffix(): String =
        System.nanoTime().toString(16).takeLast(8)
}
