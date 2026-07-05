package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object ChatAPIEndpoint {
    val chats = APIEndpoint(HTTPMethod.GET, "/chats")

    fun messages(roomId: String, limit: Int = 50, beforeId: String? = null, sinceId: String? = null): APIEndpoint =
        endpointWithQuery(
            method = HTTPMethod.GET,
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

    fun pinRoom(roomId: String, pinned: Boolean): APIEndpoint =
        APIEndpoint(if (pinned) HTTPMethod.POST else HTTPMethod.DELETE, "/rooms/$roomId/pin")

    fun updateNotificationSettings(roomId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/notification-settings")

    fun deleteMessage(roomId: String, messageId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.DELETE, "/rooms/$roomId/messages/$messageId")

    fun pinMessage(roomId: String, messageId: String, pinned: Boolean): APIEndpoint =
        APIEndpoint(if (pinned) HTTPMethod.POST else HTTPMethod.DELETE, "/rooms/$roomId/messages/$messageId/pin")

    fun addReaction(roomId: String, messageId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/messages/$messageId/reactions")

    fun removeReaction(roomId: String, messageId: String, reactionKey: String): APIEndpoint =
        endpointWithQuery(
            method = HTTPMethod.DELETE,
            path = "/rooms/$roomId/messages/$messageId/reactions",
            values = mapOf("reaction_key" to reactionKey),
        )

    private fun endpointWithQuery(method: HTTPMethod, path: String, values: Map<String, String?>): APIEndpoint =
        APIEndpoint(method, pathWithQuery(path, values))

    private fun pathWithQuery(path: String, values: Map<String, String?>): String {
        val query =
            values.entries
                .filter { (_, value) -> !value.isNullOrBlank() }
                .joinToString("&") { (key, value) ->
                    "${encode(key)}=${encode(value.orEmpty())}"
                }
        return if (query.isBlank()) path else "$path?$query"
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name())
}
