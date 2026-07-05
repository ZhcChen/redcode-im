package com.redcode.im.androidapp.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class JavaNetHttpTransport : HttpTransport {
    private val client = OkHttpClient()

    override suspend fun execute(request: HttpRequest): HttpResponse =
        withContext(Dispatchers.IO) {
            val requestBody = request.body?.toRequestBody(JSON_MEDIA_TYPE)
            val bodyForMethod =
                when {
                    request.method == HTTPMethod.GET -> null
                    requestBody != null -> requestBody
                    request.method == HTTPMethod.POST || request.method == HTTPMethod.PATCH -> ByteArray(0).toRequestBody(JSON_MEDIA_TYPE)
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
                HttpResponse(
                    statusCode = response.code,
                    body = response.body?.string().orEmpty(),
                )
            }
        }

    private companion object {
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    }
}
