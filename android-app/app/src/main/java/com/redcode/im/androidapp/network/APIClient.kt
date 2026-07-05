package com.redcode.im.androidapp.network

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

class APIClient(
    @PublishedApi internal val environment: RedCodeEnvironment,
    @PublishedApi internal val transport: HttpTransport = JavaNetHttpTransport(),
    @PublishedApi internal val json: Json =
        Json {
            ignoreUnknownKeys = true
        },
) {
    suspend inline fun <reified Response : Any> get(
        endpoint: APIEndpoint,
        bearerToken: String? = null,
    ): Response =
        send(endpoint = endpoint, bearerToken = bearerToken, body = null)

    suspend inline fun <reified Body : Any, reified Response : Any> post(
        endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = null,
    ): Response =
        send(endpoint = endpoint, bearerToken = bearerToken, body = json.encodeToString(body))

    suspend inline fun <reified Body : Any, reified Response : Any> patch(
        endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = null,
    ): Response =
        send(endpoint = endpoint, bearerToken = bearerToken, body = json.encodeToString(body))

    suspend inline fun <reified Body : Any> postNoResponse(
        endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = null,
    ) {
        sendNoResponse(endpoint = endpoint, bearerToken = bearerToken, body = json.encodeToString(body))
    }

    suspend inline fun <reified Body : Any> patchNoResponse(
        endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = null,
    ) {
        sendNoResponse(endpoint = endpoint, bearerToken = bearerToken, body = json.encodeToString(body))
    }

    suspend fun sendNoResponse(
        endpoint: APIEndpoint,
        bearerToken: String? = null,
        body: String? = null,
    ) {
        executeRaw(endpoint = endpoint, bearerToken = bearerToken, body = body)
    }

    suspend inline fun <reified Response : Any> send(
        endpoint: APIEndpoint,
        bearerToken: String? = null,
        body: String? = null,
    ): Response {
        val responseBody = executeRaw(endpoint = endpoint, bearerToken = bearerToken, body = body)
        return try {
            json.decodeFromString(responseBody)
        } catch (error: SerializationException) {
            throw NetworkFailure(message = "响应解析失败", cause = error)
        }
    }

    @PublishedApi
    internal suspend fun executeRaw(
        endpoint: APIEndpoint,
        bearerToken: String? = null,
        body: String? = null,
    ): String {
        val headers = linkedMapOf("Accept" to "application/json")
        if (body != null) headers["Content-Type"] = "application/json"
        if (!bearerToken.isNullOrBlank()) headers["Authorization"] = "Bearer $bearerToken"

        val response =
            transport.execute(
                HttpRequest(
                    method = endpoint.method,
                    url = endpoint.url(environment),
                    headers = headers,
                    body = body,
                ),
            )
        if (response.statusCode !in 200..299) {
            throw NetworkFailure(
                statusCode = response.statusCode,
                message = extractErrorMessage(response.body) ?: "HTTP ${response.statusCode}",
            )
        }
        return response.body
    }

    fun extractErrorMessage(body: String): String? =
        runCatching {
            val element = json.parseToJsonElement(body)
            val obj = element as? JsonObject ?: return null
            listOf("message", "error", "detail")
                .firstNotNullOfOrNull { key ->
                    obj[key]?.jsonPrimitive?.content?.trim()?.takeIf { it.isNotBlank() }
                }
        }.getOrNull()
}
