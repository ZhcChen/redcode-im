package com.redcode.im.androidapp.data.emoji

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import java.net.URLEncoder

object EmojiAPIEndpoint {
    val myPacks = APIEndpoint(HTTPMethod.GET, "/emoji-packs/my")

    fun downloadUrl(objectKey: String, expiresInSeconds: Int = 3_600): APIEndpoint =
        endpointWithQuery(
            method = HTTPMethod.GET,
            path = "/emoji-packs/download-url",
            values =
                mapOf(
                    "object_key" to objectKey,
                    "expires_in_seconds" to expiresInSeconds.coerceIn(60, 86_400).toString(),
                ),
        )

    private fun endpointWithQuery(method: HTTPMethod, path: String, values: Map<String, String?>): APIEndpoint {
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
