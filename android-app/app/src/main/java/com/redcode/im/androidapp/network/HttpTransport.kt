package com.redcode.im.androidapp.network

data class HttpRequest(
    val method: HTTPMethod,
    val url: String,
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
    val bodyBytes: ByteArray? = null,
    val contentType: String? = null,
)

data class HttpResponse(
    val statusCode: Int,
    val body: String,
    val bodyBytes: ByteArray = body.toByteArray(Charsets.UTF_8),
)

interface HttpTransport {
    suspend fun execute(request: HttpRequest): HttpResponse
}
