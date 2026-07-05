package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.contacts.BackendFriendRequest
import com.redcode.im.androidapp.data.contacts.BackendUser
import com.redcode.im.androidapp.data.contacts.FriendAPIEndpoint
import com.redcode.im.androidapp.data.contacts.HttpFriendRemoteDataSource
import com.redcode.im.androidapp.data.contacts.RemoteContactsRepository
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.HttpRequest
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.HttpTransport
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteContactsRepositoryTest {
    @Test
    fun friendEndpoint_buildsSearchAndRequestQueries() {
        assertEquals(
            "http://10.0.2.2:8010/users/search?keyword=alice+bob&limit=50",
            FriendAPIEndpoint.searchUsers("alice bob", limit = 99).url(RedCodeEnvironment.localEmulator()),
        )
        assertEquals(
            "http://10.0.2.2:8010/friends/requests?direction=incoming&status=pending",
            FriendAPIEndpoint.friendRequests(direction = "incoming", status = "pending").url(RedCodeEnvironment.localEmulator()),
        )
    }

    @Test
    fun refreshAndSearch_useRemoteFriendEndpoints() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(200, """[{"id":"f-1","friend_remark":"Ali","user":{"id":"user-a","username":"alice","nickname":"Alice"}}]"""),
                    HttpResponse(200, """[{"id":"user-b","username":"bob","nickname":"Bob"}]"""),
                )
            val repository = repository(transport)

            repository.refreshContacts()
            val results = repository.search("bob")

            assertEquals("Ali", repository.contacts.value.single().displayName)
            assertEquals("Bob", results.single().displayName)
            assertEquals("http://10.0.2.2:8010/friends", transport.requests[0].url)
            assertEquals("http://10.0.2.2:8010/users/search?keyword=bob&limit=20", transport.requests[1].url)
            assertEquals("Bearer access-token", transport.requests[1].headers["Authorization"])
        }

    @Test
    fun blankSearch_skipsNetwork() =
        runTest {
            val transport = QueueTransport()
            val dataSource = HttpFriendRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val results = dataSource.searchUsers("   ", token = "token")

            assertEquals(emptyList<Contact>(), results.map { it.toContact() })
            assertEquals(emptyList<HttpRequest>(), transport.requests)
        }

    @Test
    fun fetchAndDeclineFriendRequests_useExpectedEndpoints() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """[{"id":"req-1","requester":{"id":"user-b","username":"bob"},"addressee":{"id":"user-me","username":"me"},"status":"pending","is_incoming":true}]""",
                    ),
                    HttpResponse(
                        200,
                        """{"id":"req-1","requester":{"id":"user-b","username":"bob"},"addressee":{"id":"user-me","username":"me"},"status":"declined","is_incoming":true}""",
                    ),
                )
            val dataSource = HttpFriendRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val requests = dataSource.fetchFriendRequests(direction = "incoming", status = "pending", token = "token")
            val declined = dataSource.respondFriendRequest(requestId = "req-1", accept = false, token = "token")

            assertEquals(FriendRequestStatus.Pending, requests.single().toDomain().status)
            assertEquals(FriendRequestStatus.Declined, declined.toDomain().status)
            assertEquals("http://10.0.2.2:8010/friends/requests?direction=incoming&status=pending", transport.requests[0].url)
            assertEquals("""{"action":"decline"}""", transport.requests[1].body)
        }

    @Test
    fun addContactAndEnsurePrivateChat_callFriendApis() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """{"id":"req-1","requester":{"id":"user-me","username":"me"},"addressee":{"id":"user-b","username":"bob"},"status":"pending","is_incoming":false}""",
                    ),
                    HttpResponse(200, """{"room_id":"room-private","room_name":"Bob"}"""),
                )
            val repository = repository(transport)

            repository.addLocalContact(Contact(userId = "user-b", accountName = "bob", displayName = "Bob"))
            val roomId = repository.ensurePrivateChat("user-b")

            assertEquals("room-private", roomId)
            assertEquals(HTTPMethod.POST, transport.requests[0].method)
            assertEquals("http://10.0.2.2:8010/friends/requests", transport.requests[0].url)
            assertEquals("""{"target_user_id":"user-b"}""", transport.requests[0].body)
            assertEquals("http://10.0.2.2:8010/friends/user-b/chat", transport.requests[1].url)
        }

    @Test
    fun respondFriendRequest_refreshesContactsWhenAccepted() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """{"id":"req-1","requester":{"id":"user-b","username":"bob"},"addressee":{"id":"user-me","username":"me"},"status":"accepted","is_incoming":true}""",
                    ),
                    HttpResponse(200, """[{"id":"f-1","user":{"id":"user-b","username":"bob","nickname":"Bob"}}]"""),
                )
            val repository = repository(transport)

            repository.respondFriendRequest("req-1", accept = true)

            assertEquals("""{"action":"accept"}""", transport.requests[0].body)
            assertEquals("Bob", repository.contacts.value.single().displayName)
        }

    @Test
    fun missingToken_rejectsRemoteContactsOperations() =
        runTest {
            val repository =
                RemoteContactsRepository(
                    remoteDataSource = HttpFriendRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), QueueTransport())),
                    session = MutableStateFlow(null),
                )

            assertTrue(runCatching { repository.refreshContacts() }.exceptionOrNull() is IllegalStateException)
        }

    @Test
    fun backendFriendRequest_mapsCounterpartyAndStatus() {
        val request =
            BackendFriendRequest(
                id = "req-1",
                requester = BackendUser(id = "user-a", username = "alice"),
                addressee = BackendUser(id = "user-b", nickname = "Bob"),
                status = "declined",
                isIncoming = false,
            ).toDomain()
        val accepted =
            BackendFriendRequest(
                id = "req-2",
                requester = BackendUser(id = "user-a", username = "alice"),
                addressee = BackendUser(id = "user-b", username = "bob"),
                status = "accepted",
                isIncoming = true,
            ).toDomain()

        assertEquals("user-b", request.fromUserId)
        assertEquals("Bob", request.fromDisplayName)
        assertEquals(FriendRequestStatus.Declined, request.status)
        assertEquals(FriendRequestStatus.Accepted, accepted.status)
    }

    private fun repository(transport: QueueTransport): RemoteContactsRepository =
        RemoteContactsRepository(
            remoteDataSource = HttpFriendRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport)),
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
