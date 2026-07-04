package com.redcode.im.androidapp.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.data.auth.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
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
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

data class AuthUiState(
    val mode: AuthMode = AuthMode.Login,
    val accountName: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val session: AuthSession? = null,
)

class AuthViewModel(
    private val authRepository: AuthRepository,
) : ViewModel() {
    private val formState = MutableStateFlow(AuthFormState())

    val uiState: StateFlow<AuthUiState> =
        combine(formState, authRepository.session) { form, session ->
            AuthUiState(
                mode = form.mode,
                accountName = form.accountName,
                password = form.password,
                isLoading = form.isLoading,
                errorMessage = form.errorMessage,
                session = session,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AuthUiState())

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

    fun submit() {
        val snapshot = formState.value
        viewModelScope.launch {
            formState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                if (snapshot.mode == AuthMode.Login) {
                    authRepository.login(snapshot.accountName, snapshot.password)
                } else {
                    authRepository.register(snapshot.accountName, snapshot.password)
                }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "认证失败") }
            }
            formState.update { it.copy(isLoading = false) }
        }
    }

    fun logout() {
        viewModelScope.launch {
            authRepository.logout()
        }
    }
}
