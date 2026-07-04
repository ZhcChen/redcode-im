package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.data.auth.AuthRemoteDataSource
import com.redcode.im.androidapp.data.auth.BackendAuthSession
import com.redcode.im.androidapp.data.auth.BackendAuthUser
import com.redcode.im.androidapp.data.auth.InMemoryAuthSessionStore
import com.redcode.im.androidapp.data.auth.RemoteAuthRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteAuthRepositoryTest {
    @Test
    fun login_validatesCredentialsAndStoresSession() =
        runTest {
            val remote = FakeAuthRemoteDataSource()
            val store = InMemoryAuthSessionStore()
            val repository = RemoteAuthRepository(remote, store)

            val session = repository.login("  Tester  ", "password1")

            assertEquals("tester", remote.loginCalls.single().first)
            assertEquals("token-tester", session.tokens.accessToken)
            assertEquals(session, store.session.value)
        }

    @Test
    fun register_createsUserThenLogsInAndStoresSession() =
        runTest {
            val remote = FakeAuthRemoteDataSource()
            val store = InMemoryAuthSessionStore()
            val repository = RemoteAuthRepository(remote, store)

            val session = repository.register("tester", "password1")

            assertEquals("tester", remote.registerCalls.single().username)
            assertEquals("tester", remote.loginCalls.single().first)
            assertEquals("tester", session.user.accountName)
            assertEquals(session, repository.session.value)
        }

    @Test
    fun logout_clearsStoredSession() =
        runTest {
            val initial = BackendAuthSession("token", "refresh", BackendAuthUser("user-1", username = "tester")).toDomain()
            val store = InMemoryAuthSessionStore(initial)
            val repository = RemoteAuthRepository(FakeAuthRemoteDataSource(), store)

            repository.logout()

            assertNull(repository.session.value)
        }

    @Test
    fun login_rejectsEmailAccountBeforeNetwork() =
        runTest {
            val remote = FakeAuthRemoteDataSource()
            val repository = RemoteAuthRepository(remote, InMemoryAuthSessionStore())

            val error = runCatching { repository.login("tester@example.com", "password1") }.exceptionOrNull()

            assertTrue(error is IllegalArgumentException)
            assertEquals(emptyList<Pair<String, String>>(), remote.loginCalls)
        }

    private data class RegisterCall(val username: String, val password: String, val nickname: String)

    private class FakeAuthRemoteDataSource : AuthRemoteDataSource {
        val registerCalls = mutableListOf<RegisterCall>()
        val loginCalls = mutableListOf<Pair<String, String>>()

        override suspend fun register(username: String, password: String, nickname: String): BackendAuthUser {
            registerCalls += RegisterCall(username, password, nickname)
            return BackendAuthUser(id = "user-$username", username = username, nickname = nickname)
        }

        override suspend fun login(username: String, password: String): BackendAuthSession {
            loginCalls += username to password
            return BackendAuthSession(
                token = "token-$username",
                refreshToken = "refresh-$username",
                user = BackendAuthUser(id = "user-$username", username = username, nickname = username),
            )
        }

        override suspend fun me(token: String): BackendAuthUser =
            BackendAuthUser(id = "user-me", username = "me")

        override suspend fun refresh(refreshToken: String): BackendAuthSession =
            BackendAuthSession(
                token = "token-refreshed",
                refreshToken = refreshToken,
                user = BackendAuthUser(id = "user-me", username = "me"),
            )
    }
}
