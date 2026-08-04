package com.redcode.im.androidapp.network

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.Serializable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class APIClientTest {
    @Test
    fun endpoint_buildsUrlFromEnvironment() {
        val environment = RedCodeEnvironment("http://127.0.0.1:8010/", "ws://127.0.0.1:8010/ws")

        assertEquals(
            "http://127.0.0.1:8010/auth/login",
            APIEndpoint(HTTPMethod.POST, "/auth/login").url(environment),
        )
        assertThrows(IllegalArgumentException::class.java) {
            APIEndpoint(HTTPMethod.GET, "auth/me")
        }
    }

    @Test
    fun post_setsJsonHeadersAuthorizationAndDecodesResponse() =
        runTest {
            val transport = RecordingTransport(HttpResponse(200, """{"value":"ok","ignored":1}"""))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)

            val response =
                client.post<TestRequest, TestResponse>(
                    APIEndpoint(HTTPMethod.POST, "/auth/login"),
                    TestRequest("tester"),
                    bearerToken = "token-1",
                )

            assertEquals("ok", response.value)
            assertEquals(HTTPMethod.POST, transport.lastRequest.method)
            assertEquals("http://10.0.2.2:8010/auth/login", transport.lastRequest.url)
            assertEquals("application/json", transport.lastRequest.headers["Accept"])
            assertEquals("application/json", transport.lastRequest.headers["Content-Type"])
            assertEquals("Bearer token-1", transport.lastRequest.headers["Authorization"])
            assertEquals("""{"name":"tester"}""", transport.lastRequest.body)
        }

    @Test
    fun get_omitsBodyAndContentType() =
        runTest {
            val transport = RecordingTransport(HttpResponse(200, """{"value":"me"}"""))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)

            val response: TestResponse = client.get(APIEndpoint(HTTPMethod.GET, "/auth/me"))

            assertEquals("me", response.value)
            assertEquals(null, transport.lastRequest.body)
            assertEquals(false, transport.lastRequest.headers.containsKey("Content-Type"))
        }

    @Test
    fun httpError_extractsBackendMessage() =
        runTest {
            val client =
                APIClient(
                    RedCodeEnvironment.localEmulator(),
                    RecordingTransport(HttpResponse(401, """{"message":"账号或密码错误"}""")),
                )

            val error = runCatching { client.get<TestResponse>(APIEndpoint(HTTPMethod.GET, "/auth/me")) }.exceptionOrNull()
            assertEquals(true, error is NetworkFailure)
            error as NetworkFailure
            assertEquals(401, error.statusCode)
            assertEquals("账号或密码错误", error.message)
        }

    @Test
    fun invalidJson_throwsDecodingFailure() =
        runTest {
            val client =
                APIClient(
                    RedCodeEnvironment.localEmulator(),
                    RecordingTransport(HttpResponse(200, """{"unexpected":true}""")),
                )

            val error = runCatching { client.get<TestResponse>(APIEndpoint(HTTPMethod.GET, "/auth/me")) }.exceptionOrNull()
            assertEquals(true, error is NetworkFailure)
            error as NetworkFailure
            assertEquals("响应解析失败", error.message)
        }

    @Test
    fun sendNoResponse_acceptsEmptySuccessBody() =
        runTest {
            val transport = RecordingTransport(HttpResponse(204, ""))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)

            client.sendNoResponse(APIEndpoint(HTTPMethod.DELETE, "/rooms/room-1/rules/rule-1"), bearerToken = "token-1")

            assertEquals(HTTPMethod.DELETE, transport.lastRequest.method)
            assertEquals("Bearer token-1", transport.lastRequest.headers["Authorization"])
        }

    @Test
    fun uploadBytes_sendsRawBodyToAbsoluteUrl() =
        runTest {
            val transport = RecordingTransport(HttpResponse(200, "ok"))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)
            val bytes = "image-bytes".encodeToByteArray()

            client.uploadBytes(
                url = "http://127.0.0.1:19080/mock-bucket/messages/r1/a.png",
                method = HTTPMethod.PUT,
                headers = mapOf("X-Test" to "1"),
                bytes = bytes,
                contentType = "image/png",
            )

            assertEquals(HTTPMethod.PUT, transport.lastRequest.method)
            assertEquals("http://127.0.0.1:19080/mock-bucket/messages/r1/a.png", transport.lastRequest.url)
            assertEquals("1", transport.lastRequest.headers["X-Test"])
            assertEquals("image/png", transport.lastRequest.headers["Content-Type"])
            assertEquals(null, transport.lastRequest.body)
            assertEquals(bytes.toList(), transport.lastRequest.bodyBytes?.toList())
        }

    @Test
    fun downloadBytes_returnsRawBodyFromAbsoluteUrl() =
        runTest {
            val bytes = byteArrayOf(0, 1, 2, 3)
            val transport = RecordingTransport(HttpResponse(statusCode = 200, body = "", bodyBytes = bytes))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)

            val downloaded = client.downloadBytes("http://127.0.0.1:19080/mock-bucket/a.bin")

            assertEquals(HTTPMethod.GET, transport.lastRequest.method)
            assertEquals("http://127.0.0.1:19080/mock-bucket/a.bin", transport.lastRequest.url)
            assertEquals(bytes.toList(), downloaded.toList())
        }

    @Test
    fun downloadBytes_passesMaxResponseBytesToTransport() =
        runTest {
            val bytes = byteArrayOf(0, 1, 2, 3)
            val transport = RecordingTransport(HttpResponse(statusCode = 200, body = "", bodyBytes = bytes))
            val client = APIClient(RedCodeEnvironment.localEmulator(), transport)

            client.downloadBytes("http://127.0.0.1:19080/mock-bucket/a.bin", maxBytes = 1024)

            assertEquals(1024L, transport.lastRequest.maxResponseBytes)
        }

    @Serializable
    private data class TestRequest(val name: String)

    @Serializable
    private data class TestResponse(val value: String)
}

class RecordingTransport(
    private val response: HttpResponse,
) : HttpTransport {
    lateinit var lastRequest: HttpRequest
        private set

    override suspend fun execute(request: HttpRequest): HttpResponse {
        lastRequest = request
        return response
    }
}
