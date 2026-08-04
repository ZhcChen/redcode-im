package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.rooms.BackendGroupJoinRequest
import com.redcode.im.androidapp.data.rooms.HttpRoomRemoteDataSource
import com.redcode.im.androidapp.data.rooms.RemoteRoomRepository
import com.redcode.im.androidapp.data.rooms.RoomAPIEndpoint
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.HttpRequest
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.HttpTransport
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteRoomRepositoryTest {
    @Test
    fun roomEndpoint_buildsManagementPathsAndQueries() {
        val environment = RedCodeEnvironment.localEmulator()

        assertEquals("http://10.0.2.2:8010/rooms", RoomAPIEndpoint.createRoom.url(environment))
        assertEquals(HTTPMethod.POST, RoomAPIEndpoint.createRoom.method)
        assertEquals("http://10.0.2.2:8010/rooms/room-1", RoomAPIEndpoint.room("room-1").url(environment))
        assertEquals(HTTPMethod.PATCH, RoomAPIEndpoint.room("room-1", HTTPMethod.PATCH).method)
        assertEquals("http://10.0.2.2:8010/rooms/room-1/members/add", RoomAPIEndpoint.addMembers("room-1").url(environment))
        assertEquals("http://10.0.2.2:8010/rooms/room-1/admins/admin-1", RoomAPIEndpoint.admin("room-1", "admin-1").url(environment))
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/operation-logs?limit=100&offset=0",
            RoomAPIEndpoint.operationLogs("room-1", limit = 999, offset = -1).url(environment),
        )
    }

    @Test
    fun createGroupAndRefreshDetails_useRemoteContracts() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(
                        200,
                        """
                        {"room":{"id":"room-1","name":"Android Group","room_type":"group","description":"desc","avatar_object_key":"room_avatars/room-1/a.png","owner_id":"user-me","created_at":"2026-07-05T00:00:00Z","updated_at":"2026-07-05T00:00:01Z"}}
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        [
                          {"user_id":"user-me","username":"me","role":"owner","joined_at":"2026-07-05T00:00:00Z"},
                          {"user_id":"user-b","username":"bob","nickname":"Bob","avatar_object_key":"avatars/user-b/b.png","role":"member","joined_at":"2026-07-05T00:00:00Z"}
                        ]
                        """.trimIndent(),
                    ),
                    HttpResponse(
                        200,
                        """
                        {"settings":{"room_id":"room-1","join_approval_required":false,"member_can_invite":true,"member_can_add_friends":true,"require_admin_to_add_friends":false,"max_members":500,"global_mute_enabled":false}}
                        """.trimIndent(),
                    ),
                )
            val repository = repository(transport)

            val room = repository.createGroup(" Android Group ", " desc ", listOf("user-b", "user-b"))
            val members = repository.refreshMembers(room.id)
            val settings = repository.fetchGroupSettings(room.id)

            assertEquals("room-1", room.id)
            assertEquals("room_avatars/room-1/a.png", room.avatarObjectKey)
            assertEquals("Android Group", repository.rooms.first().single().name)
            assertEquals(listOf("user-me", "user-b"), members.map { it.userId })
            assertEquals("Bob", members[1].displayName)
            assertEquals("avatars/user-b/b.png", members[1].avatarObjectKey)
            assertEquals(500, settings.settings.maxMembers)
            assertEquals("Bearer access-token", transport.requests.first().headers["Authorization"])
            assertEquals("""{"name":"Android Group","description":"desc","room_type":"group","member_ids":["user-b"]}""", transport.requests.first().body)
        }

    @Test
    fun updateMembersSettingsAdminsMutesRulesAndLogs_callExpectedEndpoints() =
        runTest {
            val transport =
                QueueTransport(
                    HttpResponse(200, """{"room":{"id":"room-1","name":"Renamed","room_type":"group","description":"updated"}}"""),
                    HttpResponse(200, """{"added_user_ids":["user-c"],"skipped_user_ids":[]}"""),
                    HttpResponse(200, """[{"user_id":"user-c","username":"cici","role":"member"}]"""),
                    HttpResponse(200, """{"settings":{"room_id":"room-1","join_approval_required":true,"member_can_invite":true,"member_can_add_friends":true,"require_admin_to_add_friends":false,"max_members":500,"global_mute_enabled":false}}"""),
                    HttpResponse(200, """{"settings":{"room_id":"room-1","join_approval_required":true,"member_can_invite":true,"member_can_add_friends":true,"require_admin_to_add_friends":false,"max_members":500,"global_mute_enabled":true,"global_mute_reason":"smoke"}}"""),
                    HttpResponse(200, """{}"""),
                    HttpResponse(200, """{"admin":{"id":"admin-row","room_id":"room-1","admin_id":"user-c","appointed_by":"user-me","role":"admin","permissions":[]}}"""),
                    HttpResponse(204, ""),
                    HttpResponse(200, """{"mute":{"id":"mute-1","room_id":"room-1","user_id":"user-c","muted_by":"user-me","reason":"test","mute_duration_hours":1,"is_active":true}}"""),
                    HttpResponse(204, ""),
                    HttpResponse(200, """{"rule":{"id":"rule-1","room_id":"room-1","title":"Rule","content":"Content","creator_id":"user-me","order_index":0,"is_active":true}}"""),
                    HttpResponse(200, """{"rule":{"id":"rule-1","room_id":"room-1","title":"Rule","content":"Content","creator_id":"user-me","order_index":0,"is_active":false}}"""),
                    HttpResponse(204, ""),
                    HttpResponse(200, """{"logs":[{"id":"log-1","room_id":"room-1","operator_id":"user-me","operation_type":"create_rule"}],"total":1}"""),
                )
            val repository = repository(transport)

            val renamed = repository.updateRoom("room-1", name = "Renamed", description = "updated")
            val addResult = repository.addMembers("room-1", listOf("user-c"))
            val settings = repository.updateGroupSettings("room-1", joinApprovalRequired = true)
            val mutedSettings = repository.updateGlobalMute("room-1", enabled = true, reason = "smoke", durationMinutes = 30)
            repository.setRoomPinned("room-1", true)
            val admin = repository.appointAdmin("room-1", "user-c")
            repository.removeAdmin("room-1", "user-c")
            val mute = repository.muteUser("room-1", "user-c", reason = "test", muteDurationHours = 1)
            repository.unmuteUser("room-1", "user-c")
            val rule = repository.createRule("room-1", "Rule", "Content")
            val inactive = repository.updateRule("room-1", "rule-1", isActive = false)
            repository.deleteRule("room-1", "rule-1")
            val logs = repository.listOperationLogs("room-1")

            assertEquals("Renamed", renamed.name)
            assertEquals(listOf("user-c"), addResult.addedUserIds)
            assertEquals(true, settings.settings.joinApprovalRequired)
            assertEquals(true, mutedSettings.settings.globalMuteEnabled)
            assertEquals("user-c", admin.adminId)
            assertEquals("user-c", mute.userId)
            assertEquals("Rule", rule.title)
            assertEquals(false, inactive.isActive)
            assertEquals("create_rule", logs.single().operationType)
            assertEquals(HTTPMethod.PATCH, transport.requests[0].method)
            assertEquals("""{"name":"Renamed","description":"updated"}""", transport.requests[0].body)
            assertEquals("""{"user_id":"user-c","role":"admin"}""", transport.requests[6].body)
            assertEquals("http://10.0.2.2:8010/rooms/room-1/admins/user-c", transport.requests[7].url)
        }

    @Test
    fun backendJoinRequest_mapsNumericAndStringStatuses() {
        val approved =
            BackendGroupJoinRequest(
                id = "req-1",
                roomId = "room-1",
                applicantId = "user-a",
                status = kotlinx.serialization.json.JsonPrimitive(1),
            ).toDomain()
        val rejected =
            BackendGroupJoinRequest(
                id = "req-2",
                roomId = "room-1",
                applicantId = "user-a",
                status = kotlinx.serialization.json.JsonPrimitive("rejected"),
            ).toDomain()

        assertEquals(com.redcode.im.androidapp.core.model.JoinRequestStatus.Approved, approved.status)
        assertEquals(com.redcode.im.androidapp.core.model.JoinRequestStatus.Rejected, rejected.status)
    }

    @Test
    fun missingToken_rejectsRemoteRoomOperations() =
        runTest {
            val repository =
                RemoteRoomRepository(
                    remoteDataSource = HttpRoomRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), QueueTransport())),
                    session = MutableStateFlow(null),
                )

            assertTrue(runCatching { repository.refreshRooms() }.exceptionOrNull() is IllegalStateException)
        }

    private fun repository(transport: QueueTransport): RemoteRoomRepository =
        RemoteRoomRepository(
            remoteDataSource = HttpRoomRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport)),
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
