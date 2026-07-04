package com.redcode.im.androidapp.network

data class HttpRequest(
    val method: HTTPMethod,
    val url: String,
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
)

data class HttpResponse(
    val statusCode: Int,
    val body: String,
)

interface HttpTransport {
    suspend fun execute(request: HttpRequest): HttpResponse
}
