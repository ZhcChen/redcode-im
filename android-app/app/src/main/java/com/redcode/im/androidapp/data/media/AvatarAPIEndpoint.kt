package com.redcode.im.androidapp.data.media

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object AvatarAPIEndpoint {
    fun currentUserAvatarDownloadUrl(expiresInSeconds: Int = 3_600): APIEndpoint =
        withQuery(
            path = "/users/me/avatar/url",
            values = mapOf("expires_in_seconds" to expiresInSeconds.coerceIn(60, 86_400).toString()),
        )

    fun userAvatarDownloadUrl(userId: String, expiresInSeconds: Int = 3_600): APIEndpoint =
        withQuery(
            path = "/users/${encode(userId)}/avatar/url",
            values = mapOf("expires_in_seconds" to expiresInSeconds.coerceIn(60, 86_400).toString()),
        )

    fun roomAvatarDownloadUrl(roomId: String, expiresInSeconds: Int = 3_600): APIEndpoint =
        withQuery(
            path = "/rooms/${encode(roomId)}/avatar/url",
            values = mapOf("expires_in_seconds" to expiresInSeconds.coerceIn(60, 86_400).toString()),
        )

    private fun withQuery(path: String, values: Map<String, String?>): APIEndpoint {
        val query =
            values.entries
                .filter { (_, value) -> !value.isNullOrBlank() }
                .joinToString("&") { (key, value) -> "${encode(key)}=${encode(value.orEmpty())}" }
        return APIEndpoint(HTTPMethod.GET, if (query.isBlank()) path else "$path?$query")
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name())
}
