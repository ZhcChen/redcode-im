package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.StateFlow

interface AuthRepository {
    val session: StateFlow<AuthSession?>

    suspend fun login(accountName: String, password: String): AuthSession

    suspend fun register(accountName: String, password: String): AuthSession

    suspend fun logout()
}
