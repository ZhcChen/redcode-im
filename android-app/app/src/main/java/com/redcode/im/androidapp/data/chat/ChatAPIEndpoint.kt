package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object ChatAPIEndpoint {
    val chats = APIEndpoint(HTTPMethod.GET, "/chats")

    fun messages(roomId: String, limit: Int = 50, beforeId: String? = null, sinceId: String? = null): APIEndpoint =
        withQuery(
            path = "/rooms/$roomId/messages",
            values =
                mapOf(
                    "limit" to limit.coerceIn(1, 200).toString(),
                    "before_id" to beforeId,
                    "since_id" to sinceId,
                ),
        )

    fun sendMessage(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/messages")

    fun markMessagesRead(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/messages/read")

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
