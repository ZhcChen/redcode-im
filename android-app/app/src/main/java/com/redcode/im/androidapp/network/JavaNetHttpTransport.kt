package com.redcode.im.androidapp.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Duration

class JavaNetHttpTransport : HttpTransport {
    private val client =
        OkHttpClient
            .Builder()
            .connectTimeout(DEFAULT_TIMEOUT)
            .readTimeout(DEFAULT_TIMEOUT)
            .writeTimeout(DEFAULT_TIMEOUT)
            .callTimeout(CALL_TIMEOUT)
            .build()

    override suspend fun execute(request: HttpRequest): HttpResponse =
        withContext(Dispatchers.IO) {
            val requestMediaType =
                request.contentType
                    ?.takeIf { it.isNotBlank() }
                    ?.toMediaTypeOrNull()
                    ?: request.headers.entries
                        .firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }
                        ?.value
                        ?.takeIf { it.isNotBlank() }
                        ?.toMediaTypeOrNull()
            val requestBody =
                request.bodyBytes?.toRequestBody(requestMediaType ?: BINARY_MEDIA_TYPE)
                    ?: request.body?.toRequestBody(requestMediaType ?: JSON_MEDIA_TYPE)
            val bodyForMethod =
                when {
                    request.method == HTTPMethod.GET -> null
                    requestBody != null -> requestBody
                    request.method == HTTPMethod.POST || request.method == HTTPMethod.PUT || request.method == HTTPMethod.PATCH ->
                        ByteArray(0).toRequestBody(requestMediaType ?: JSON_MEDIA_TYPE)
                    else -> null
                }
            val okHttpRequest =
                Request.Builder()
                    .url(request.url)
                    .also { builder ->
                        request.headers.forEach { (key, value) -> builder.header(key, value) }
                    }
                    .method(request.method.name, bodyForMethod)
                    .build()

            client.newCall(okHttpRequest).execute().use { response ->
                val bytes =
                    response.body?.let { body ->
                        request.maxResponseBytes?.let { maxBytes ->
                            val contentLength = body.contentLength()
                            if (contentLength > maxBytes) {
                                throw NetworkFailure(statusCode = response.code, message = "响应体超过大小限制")
                            }
                            body.byteStream().use { stream ->
                                stream.readLimited(maxBytes)
                            }
                        } ?: body.bytes()
                    } ?: ByteArray(0)
                HttpResponse(
                    statusCode = response.code,
                    body = bytes.toString(Charsets.UTF_8),
                    bodyBytes = bytes,
                )
            }
        }

    private fun java.io.InputStream.readLimited(maxBytes: Long): ByteArray {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        val output = java.io.ByteArrayOutputStream()
        var total = 0L
        while (true) {
            val read = read(buffer)
            if (read == -1) break
            total += read
            if (total > maxBytes) {
                throw NetworkFailure(message = "响应体超过大小限制")
            }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private companion object {
        val DEFAULT_TIMEOUT: Duration = Duration.ofSeconds(15)
        val CALL_TIMEOUT: Duration = Duration.ofSeconds(30)
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        val BINARY_MEDIA_TYPE = "application/octet-stream".toMediaType()
    }
}
