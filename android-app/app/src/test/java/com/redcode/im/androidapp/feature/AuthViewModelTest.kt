package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import com.redcode.im.androidapp.feature.auth.AuthMode
import com.redcode.im.androidapp.feature.auth.AuthViewModel
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
            val viewModel = AuthViewModel(InMemoryAuthRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.toggleMode()
            advanceUntilIdle()
            assertEquals(AuthMode.Register, viewModel.uiState.value.mode)
            viewModel.onAccountNameChange("tester")
            viewModel.onPasswordChange("password1")
            viewModel.submit()
            advanceUntilIdle()

            assertNotNull(viewModel.uiState.value.session)

            viewModel.logout()
            advanceUntilIdle()
            assertNull(viewModel.uiState.value.session)
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
            viewModel.submit()
            advanceUntilIdle()

            assertEquals("tester", viewModel.uiState.value.session?.user?.accountName)
            collectJob.cancel()
        }
}
