package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.core.validation.AccountName
import com.redcode.im.androidapp.core.validation.PasswordPolicy
import com.redcode.im.androidapp.core.validation.ValidationResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemoryAuthRepository : AuthRepository {
    private val accounts = linkedMapOf<String, String>()
    private val _session = MutableStateFlow<AuthSession?>(null)
    override val session: StateFlow<AuthSession?> = _session.asStateFlow()

    override suspend fun login(accountName: String, password: String): AuthSession {
        val normalized = validateCredentials(accountName, password)
        if (accounts[normalized] != password) {
            throw IllegalArgumentException("账号或密码错误")
        }
        return createSession(normalized).also { _session.value = it }
    }

    override suspend fun register(accountName: String, password: String): AuthSession {
        val normalized = validateCredentials(accountName, password)
        require(!accounts.containsKey(normalized)) { "账号已存在" }
        accounts[normalized] = password
        return createSession(normalized).also { _session.value = it }
    }

    override suspend fun logout() {
        _session.value = null
    }

    private fun validateCredentials(accountName: String, password: String): String {
        val normalized = AccountName.normalize(accountName)
        when (val result = AccountName.validate(normalized)) {
            ValidationResult.Valid -> Unit
            is ValidationResult.Invalid -> throw IllegalArgumentException(result.message)
        }
        when (val result = PasswordPolicy.validate(password)) {
            ValidationResult.Valid -> Unit
            is ValidationResult.Invalid -> throw IllegalArgumentException(result.message)
        }
        return normalized
    }

    private fun createSession(accountName: String): AuthSession =
        AuthSession(
            user =
                AuthUser(
                    id = "user-$accountName",
                    accountName = accountName,
                    displayName = accountName,
                ),
            tokens =
                TokenPair(
                    accessToken = "access-$accountName",
                    refreshToken = "refresh-$accountName",
                ),
        )
}
