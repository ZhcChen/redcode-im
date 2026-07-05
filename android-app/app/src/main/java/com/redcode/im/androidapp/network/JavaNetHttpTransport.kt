package com.redcode.im.androidapp.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class JavaNetHttpTransport : HttpTransport {
    private val client = OkHttpClient()

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
                val bytes = response.body?.bytes() ?: ByteArray(0)
                HttpResponse(
                    statusCode = response.code,
                    body = bytes.toString(Charsets.UTF_8),
                    bodyBytes = bytes,
                )
            }
        }

    private companion object {
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        val BINARY_MEDIA_TYPE = "application/octet-stream".toMediaType()
    }
}
