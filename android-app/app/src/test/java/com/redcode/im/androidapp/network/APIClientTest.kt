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
