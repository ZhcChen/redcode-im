package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.RecordingTransport
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class HttpAuthRemoteDataSourceTest {
    @Test
    fun register_postsAccountPayload() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(
                        200,
                        """{"id":"user-tester","username":"tester","nickname":"Tester","status":"active"}""",
                    ),
                )
            val dataSource = HttpAuthRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val user = dataSource.register("tester", "password1", "Tester")

            assertEquals("Tester", user.nickname)
            assertEquals(HTTPMethod.POST, transport.lastRequest.method)
            assertEquals("http://10.0.2.2:8010/auth/register", transport.lastRequest.url)
            assertEquals("""{"username":"tester","password":"password1","nickname":"Tester"}""", transport.lastRequest.body)
        }

    @Test
    fun login_decodesTokenPairAndUser() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(
                        200,
                        """{"token":"access","refresh_token":"refresh","user":{"id":"user-tester","username":"tester","nickname":"Tester"}}""",
                    ),
                )
            val dataSource = HttpAuthRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val session = dataSource.login("tester", "password1").toDomain()

            assertEquals("access", session.tokens.accessToken)
            assertEquals("refresh", session.tokens.refreshToken)
            assertEquals("Tester", session.user.displayName)
            assertEquals("http://10.0.2.2:8010/auth/login", transport.lastRequest.url)
        }

    @Test
    fun me_sendsBearerToken() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(200, """{"id":"user-me","username":"me","nickname":"Me"}"""),
                )
            val dataSource = HttpAuthRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val user = dataSource.me("access-token").toDomain()

            assertEquals("Me", user.displayName)
            assertEquals(HTTPMethod.GET, transport.lastRequest.method)
            assertEquals("Bearer access-token", transport.lastRequest.headers["Authorization"])
            assertEquals("http://10.0.2.2:8010/auth/me", transport.lastRequest.url)
        }

    @Test
    fun refresh_postsRefreshToken() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(
                        200,
                        """{"token":"access-2","refresh_token":"refresh-2","user":{"id":"user-me","username":"me"}}""",
                    ),
                )
            val dataSource = HttpAuthRemoteDataSource(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val session = dataSource.refresh("refresh-1").toDomain()

            assertEquals("access-2", session.tokens.accessToken)
            assertEquals("""{"refresh_token":"refresh-1"}""", transport.lastRequest.body)
        }
}
