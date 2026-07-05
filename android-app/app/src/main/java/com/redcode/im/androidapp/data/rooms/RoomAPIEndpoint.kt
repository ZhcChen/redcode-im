package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object RoomAPIEndpoint {
    val createRoom = APIEndpoint(HTTPMethod.POST, "/rooms")
    val listRooms = APIEndpoint(HTTPMethod.GET, "/rooms")

    fun room(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId")

    fun members(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.GET, "/rooms/$roomId/members")

    fun addMembers(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/members/add")

    fun member(roomId: String, userId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.DELETE, "/rooms/$roomId/members/$userId")

    fun settings(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/settings")

    fun globalMute(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/mutes/global")

    fun notificationSettings(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/notification-settings")

    fun pin(roomId: String, pinned: Boolean): APIEndpoint =
        APIEndpoint(if (pinned) HTTPMethod.POST else HTTPMethod.DELETE, "/rooms/$roomId/pin")

    fun leave(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/leave")

    fun admins(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/admins")

    fun admin(roomId: String, adminId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.DELETE, "/rooms/$roomId/admins/$adminId")

    fun mutes(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/mutes")

    fun mute(roomId: String, mutedUserId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.DELETE, "/rooms/$roomId/mutes/$mutedUserId")

    fun rules(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/rules")

    fun rule(roomId: String, ruleId: String, method: HTTPMethod): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/rules/$ruleId")

    fun joinRequests(roomId: String, method: HTTPMethod = HTTPMethod.GET): APIEndpoint =
        APIEndpoint(method, "/rooms/$roomId/join-requests")

    fun reviewJoinRequest(roomId: String, requestId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.PATCH, "/rooms/$roomId/join-requests/$requestId/review")

    fun operationLogs(roomId: String, limit: Int = 20, offset: Int = 0): APIEndpoint =
        withQuery(
            method = HTTPMethod.GET,
            path = "/rooms/$roomId/operation-logs",
            values =
                mapOf(
                    "limit" to limit.coerceIn(1, 100).toString(),
                    "offset" to offset.coerceAtLeast(0).toString(),
                ),
        )

    fun detail(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.GET, "/rooms/$roomId/detail")

    private fun withQuery(method: HTTPMethod, path: String, values: Map<String, String?>): APIEndpoint {
        val query =
            values.entries
                .filter { (_, value) -> !value.isNullOrBlank() }
                .joinToString("&") { (key, value) ->
                    "${encode(key)}=${encode(value.orEmpty())}"
                }
        return APIEndpoint(method, if (query.isBlank()) path else "$path?$query")
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name())
}
