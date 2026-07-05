package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object FriendAPIEndpoint {
    val friends = APIEndpoint(HTTPMethod.GET, "/friends")
    val createFriendRequest = APIEndpoint(HTTPMethod.POST, "/friends/requests")

    fun searchUsers(keyword: String, limit: Int = 20): APIEndpoint =
        withQuery(
            "/users/search",
            mapOf(
                "keyword" to keyword.trim(),
                "limit" to limit.coerceIn(1, 50).toString(),
            ),
        )

    fun friendRequests(direction: String? = null, status: String? = null): APIEndpoint =
        withQuery(
            "/friends/requests",
            mapOf("direction" to direction, "status" to status),
        )

    fun respondFriendRequest(requestId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/friends/requests/$requestId/respond")

    fun ensurePrivateChat(friendUserId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/friends/$friendUserId/chat")

    private fun withQuery(path: String, values: Map<String, String?>): APIEndpoint {
        val query =
            values.entries
                .filter { (_, value) -> !value.isNullOrBlank() }
                .joinToString("&") { (key, value) ->
                    "${encode(key)}=${encode(value.orEmpty())}"
                }
        return APIEndpoint(HTTPMethod.GET, if (query.isBlank()) path else "$path?$query")
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name())
}
