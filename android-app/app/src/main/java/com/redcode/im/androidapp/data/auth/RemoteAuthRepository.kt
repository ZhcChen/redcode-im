package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.validation.AccountName
import com.redcode.im.androidapp.core.validation.PasswordPolicy
import com.redcode.im.androidapp.core.validation.ValidationResult
import kotlinx.coroutines.flow.StateFlow

class RemoteAuthRepository(
    private val remoteDataSource: AuthRemoteDataSource,
    private val sessionStore: AuthSessionStore,
) : AuthRepository {
    override val session: StateFlow<AuthSession?> = sessionStore.session

    override suspend fun login(accountName: String, password: String): AuthSession {
        val username = validateCredentials(accountName, password)
        return remoteDataSource.login(username, password).toDomain().also {
            sessionStore.save(it)
        }
    }

    override suspend fun register(accountName: String, password: String): AuthSession {
        val username = validateCredentials(accountName, password)
        remoteDataSource.register(username = username, password = password, nickname = username)
        return login(username, password)
    }

    override suspend fun logout() {
        sessionStore.clear()
    }

    private fun validateCredentials(accountName: String, password: String): String {
        val normalized = AccountName.normalize(accountName).lowercase()
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
}
