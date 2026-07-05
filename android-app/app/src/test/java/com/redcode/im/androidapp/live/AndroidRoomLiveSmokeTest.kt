package com.redcode.im.androidapp.live

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.rooms.HttpRoomRemoteDataSource
import com.redcode.im.androidapp.network.APIClient
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class AndroidRoomLiveSmokeTest {
    @Test
    fun androidClientCanCompleteGroupManagementFlowAgainstComposeAPI() =
        runTest {
            assumeTrue(
                "Set RED_CODE_ANDROID_LIVE_ROOM_SMOKE=1 when the local Compose API is running",
                liveSmokeEnabled(),
            )

            val apiClient = APIClient(liveEnvironment())
            val authDataSource = HttpAuthRemoteDataSource(apiClient)
            val roomDataSource = HttpRoomRemoteDataSource(apiClient)
            val suffix = randomSuffix()
            val owner = registerAndLogin(authDataSource, "andowner$suffix")
            val member = registerAndLogin(authDataSource, "andmember$suffix")
            val extra = registerAndLogin(authDataSource, "andextra$suffix")

            val room =
                roomDataSource.createGroup(
                    name = "android group $suffix",
                    description = "group management live smoke",
                    memberIds = listOf(member.user.id),
                    token = owner.tokens.accessToken,
                )
            val renamed =
                roomDataSource.updateRoom(
                    roomId = room.id,
                    name = "android renamed $suffix",
                    description = "updated",
                    token = owner.tokens.accessToken,
                )
            val addResult = roomDataSource.addMembers(room.id, listOf(extra.user.id), owner.tokens.accessToken)
            roomDataSource.updateNotificationSettings(room.id, notificationSettings = 2, token = owner.tokens.accessToken)
            roomDataSource.setRoomPinned(room.id, pinned = true, token = owner.tokens.accessToken)
            val admin = roomDataSource.appointAdmin(room.id, extra.user.id, owner.tokens.accessToken)
            val mute =
                roomDataSource.muteUser(
                    roomId = room.id,
                    userId = member.user.id,
                    reason = "android live smoke",
                    muteDurationHours = 1,
                    token = owner.tokens.accessToken,
                )
            val rule =
                roomDataSource.createRule(
                    roomId = room.id,
                    title = "Android Rule $suffix",
                    content = "Keep the group deterministic",
                    token = owner.tokens.accessToken,
                )
            val updatedRule =
                roomDataSource.updateRule(
                    roomId = room.id,
                    ruleId = rule.id,
                    title = null,
                    content = null,
                    isActive = false,
                    token = owner.tokens.accessToken,
                )

            val members = roomDataSource.listMembers(room.id, owner.tokens.accessToken)
            val settings = roomDataSource.fetchGroupSettings(room.id, owner.tokens.accessToken)
            val admins = roomDataSource.listAdmins(room.id, owner.tokens.accessToken)
            val mutes = roomDataSource.listMutes(room.id, owner.tokens.accessToken)
            val rules = roomDataSource.listRules(room.id, owner.tokens.accessToken)
            val logs = roomDataSource.listOperationLogs(room.id, limit = 20, offset = 0, token = owner.tokens.accessToken)

            assertEquals("group", room.roomType)
            assertEquals("android renamed $suffix", renamed.name)
            assertTrue(addResult.addedUserIds.contains(extra.user.id))
            assertTrue(members.any { it.userId == owner.user.id && it.role == "owner" })
            assertTrue(members.any { it.userId == member.user.id })
            assertEquals(room.id, settings.settings.roomId)
            assertEquals(extra.user.id, admin.adminId)
            assertTrue(admins.any { it.adminId == extra.user.id })
            assertEquals(member.user.id, mute.userId)
            assertTrue(mutes.any { it.userId == member.user.id })
            assertFalse(updatedRule.isActive)
            assertTrue(rules.any { it.id == rule.id })
            assertTrue(logs.isNotEmpty())

            roomDataSource.unmuteUser(room.id, member.user.id, owner.tokens.accessToken)
            roomDataSource.removeAdmin(room.id, extra.user.id, owner.tokens.accessToken)
            roomDataSource.deleteRule(room.id, rule.id, owner.tokens.accessToken)
            roomDataSource.leaveRoom(room.id, extra.tokens.accessToken)
            roomDataSource.dissolveRoom(room.id, owner.tokens.accessToken)
        }

    private suspend fun registerAndLogin(authDataSource: HttpAuthRemoteDataSource, username: String): AuthSession {
        val password = "secret123"
        authDataSource.register(username = username, password = password, nickname = username)
        return authDataSource.login(username = username, password = password).toDomain()
    }

    private fun liveSmokeEnabled(): Boolean =
        System.getenv("RED_CODE_ANDROID_LIVE_SMOKE") == "1" ||
            System.getenv("RED_CODE_ANDROID_LIVE_ROOM_SMOKE") == "1"

    private fun liveEnvironment(): RedCodeEnvironment =
        RedCodeEnvironment(
            apiBaseUrl = System.getenv("ANDROID_APP_LIVE_API_BASE_URL") ?: "http://127.0.0.1:8010",
            wsUrl = System.getenv("ANDROID_APP_LIVE_WS_URL") ?: "ws://127.0.0.1:8010/ws",
        )

    private fun randomSuffix(): String =
        System.nanoTime().toString(16).takeLast(8)
}
