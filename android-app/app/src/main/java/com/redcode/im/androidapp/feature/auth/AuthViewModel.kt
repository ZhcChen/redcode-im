package com.redcode.im.androidapp.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.data.auth.AuthRepository
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.data.preferences.UserPreferenceStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class AuthMode {
    Login,
    Register,
}

data class AuthFormState(
    val mode: AuthMode = AuthMode.Login,
    val accountName: String = "",
    val password: String = "",
    val hasAcceptedTerms: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

data class AuthUiState(
    val mode: AuthMode = AuthMode.Login,
    val accountName: String = "",
    val password: String = "",
    val hasAcceptedTerms: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val session: AuthSession? = null,
)

class AuthViewModel(
    private val authRepository: AuthRepository,
    private val userPreferenceStore: UserPreferenceStore = InMemoryUserPreferenceStore(),
    private val logoutCleanup: suspend () -> Unit = {},
) : ViewModel() {
    private val formState = MutableStateFlow(AuthFormState())

    val uiState: StateFlow<AuthUiState> =
        combine(formState, authRepository.session) { form, session ->
            AuthUiState(
                mode = form.mode,
                accountName = form.accountName,
                password = form.password,
                hasAcceptedTerms = form.hasAcceptedTerms,
                isLoading = form.isLoading,
                errorMessage = form.errorMessage,
                session = session,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AuthUiState())

    init {
        viewModelScope.launch {
            userPreferenceStore.acceptedTerms.collect { acceptedTerms ->
                formState.update {
                    if (it.hasAcceptedTerms == acceptedTerms) {
                        it
                    } else {
                        it.copy(hasAcceptedTerms = acceptedTerms)
                    }
                }
            }
        }
    }

    fun onAccountNameChange(value: String) {
        formState.update { it.copy(accountName = value, errorMessage = null) }
    }

    fun onPasswordChange(value: String) {
        formState.update { it.copy(password = value, errorMessage = null) }
    }

    fun toggleMode() {
        formState.update {
            it.copy(
                mode = if (it.mode == AuthMode.Login) AuthMode.Register else AuthMode.Login,
                errorMessage = null,
            )
        }
    }

    fun setAcceptedTerms(accepted: Boolean) {
        formState.update { it.copy(hasAcceptedTerms = accepted, errorMessage = null) }
        viewModelScope.launch {
            userPreferenceStore.setAcceptedTerms(accepted)
        }
    }

    fun submit() {
        val formSnapshot = formState.value
        if (!formSnapshot.hasAcceptedTerms) {
            formState.update { it.copy(errorMessage = "请勾选并阅读《用户协议》和《隐私协议》") }
            return
        }
        viewModelScope.launch {
            formState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                if (formSnapshot.mode == AuthMode.Login) {
                    authRepository.login(formSnapshot.accountName, formSnapshot.password)
                } else {
                    authRepository.register(formSnapshot.accountName, formSnapshot.password)
                }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "认证失败") }
            }
            formState.update { it.copy(isLoading = false) }
        }
    }

    fun logout() {
        viewModelScope.launch {
            val logoutError = runCatching { authRepository.logout() }.exceptionOrNull()
            val cleanupError = runCatching { logoutCleanup() }.exceptionOrNull()
            formState.update {
                it.copy(
                    accountName = "",
                    password = "",
                    errorMessage = (logoutError ?: cleanupError)?.message,
                )
            }
        }
    }
}
