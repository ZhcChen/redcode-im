package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthRepositoryTest {
    @Test
    fun register_createsSessionAndLoginReusesAccount() =
        runTest {
            val repository = InMemoryAuthRepository()

            val registered = repository.register("tester", "password1")
            assertEquals("tester", registered.user.accountName)
            assertEquals(registered, repository.session.value)

            repository.logout()
            assertNull(repository.session.value)

            val loggedIn = repository.login("tester", "password1")
            assertEquals("user-tester", loggedIn.user.id)
            assertEquals(loggedIn, repository.session.value)
        }

    @Test
    fun register_rejectsDuplicateAndEmailAccount() =
        runTest {
            val repository = InMemoryAuthRepository()
            repository.register("tester", "password1")

            assertTrue(runCatching { repository.register("tester", "password1") }.exceptionOrNull() is IllegalArgumentException)
            assertTrue(runCatching { repository.register("tester@example.com", "password1") }.exceptionOrNull() is IllegalArgumentException)
            assertTrue(runCatching { repository.register("tester2", "123") }.exceptionOrNull() is IllegalArgumentException)
        }

    @Test
    fun login_rejectsUnknownOrWrongPassword() =
        runTest {
            val repository = InMemoryAuthRepository()
            repository.register("tester", "password1")
            repository.logout()

            assertTrue(runCatching { repository.login("missing", "password1") }.exceptionOrNull() is IllegalArgumentException)
            assertTrue(runCatching { repository.login("tester", "password2") }.exceptionOrNull() is IllegalArgumentException)
        }
}
