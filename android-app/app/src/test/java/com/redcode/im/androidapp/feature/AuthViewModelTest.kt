package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import com.redcode.im.androidapp.data.auth.AuthRepository
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.feature.auth.AuthMode
import com.redcode.im.androidapp.feature.auth.AuthViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun registerAndLogout_updateUiSession() =
        runTest {
            var cleanupCalls = 0
            val viewModel =
                AuthViewModel(
                    authRepository = InMemoryAuthRepository(),
                    logoutCleanup = { cleanupCalls += 1 },
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.toggleMode()
            advanceUntilIdle()
            assertEquals(AuthMode.Register, viewModel.uiState.value.mode)
            viewModel.setAcceptedTerms(true)
            advanceUntilIdle()
            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.submit()
            advanceUntilIdle()

            assertNotNull(viewModel.uiState.value.session)

            viewModel.logout()
            advanceUntilIdle()
            assertNull(viewModel.uiState.value.session)
            assertEquals("", viewModel.uiState.value.accountName)
            assertEquals("", viewModel.uiState.value.password)
            assertEquals(1, cleanupCalls)
            collectJob.cancel()
        }

    @Test
    fun logout_reportsCleanupFailureAfterClearingSession() =
        runTest {
            val repository = InMemoryAuthRepository()
            repository.register("tester", "password1")
            val viewModel =
                AuthViewModel(
                    authRepository = repository,
                    logoutCleanup = { error("cleanup failed") },
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.logout()
            advanceUntilIdle()

            assertNull(viewModel.uiState.value.session)
            assertEquals("cleanup failed", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun submit_showsValidationError() =
        runTest {
            val viewModel = AuthViewModel(InMemoryAuthRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onAccountNameChange("email@example.com")
            viewModel.onPasswordChange("password1")
            viewModel.setAcceptedTerms(true)
            advanceUntilIdle()
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("当前已关闭邮箱登录，请使用普通账号", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun loginFailure_showsRepositoryError() =
        runTest {
            val viewModel = AuthViewModel(InMemoryAuthRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.setAcceptedTerms(true)
            advanceUntilIdle()
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("账号或密码错误", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun loginSuccess_usesLoginMode() =
        runTest {
            val repository = InMemoryAuthRepository()
            repository.register("tester", "password1")
            repository.logout()
            val viewModel = AuthViewModel(repository)
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.setAcceptedTerms(true)
            advanceUntilIdle()
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("tester", viewModel.uiState.value.session?.user?.accountName)
            collectJob.cancel()
        }

    @Test
    fun submit_requiresAgreementBeforeRepositoryCall() =
        runTest {
            val repository = InMemoryAuthRepository()
            val preferenceStore = InMemoryUserPreferenceStore(initialAcceptedTerms = false)
            val viewModel = AuthViewModel(repository, preferenceStore)
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.toggleMode()
            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("请勾选并阅读《用户协议》和《隐私协议》", viewModel.uiState.value.errorMessage)
            assertNull(viewModel.uiState.value.session)

            viewModel.setAcceptedTerms(true)
            advanceUntilIdle()
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("tester", viewModel.uiState.value.session?.user?.accountName)
            collectJob.cancel()
        }

    @Test
    fun acceptedTerms_restoresFromPreferenceStore() =
        runTest {
            val viewModel = AuthViewModel(InMemoryAuthRepository(), InMemoryUserPreferenceStore(initialAcceptedTerms = true))
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            assertEquals(true, viewModel.uiState.value.hasAcceptedTerms)
            collectJob.cancel()
        }

    @Test
    fun submit_usesFallbackErrorMessageWhenRepositoryErrorHasNoMessage() =
        runTest {
            val viewModel = AuthViewModel(FailingAuthRepository(), InMemoryUserPreferenceStore(initialAcceptedTerms = true))
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("认证失败", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    private class FailingAuthRepository : AuthRepository {
        override val session: StateFlow<AuthSession?> = MutableStateFlow(null)

        override suspend fun login(accountName: String, password: String): AuthSession {
            throw RuntimeException()
        }

        override suspend fun register(accountName: String, password: String): AuthSession {
            throw RuntimeException()
        }

        override suspend fun logout() = Unit
    }
}
