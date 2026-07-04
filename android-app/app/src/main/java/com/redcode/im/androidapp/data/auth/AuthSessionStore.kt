package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.StateFlow

interface AuthSessionStore {
    val session: StateFlow<AuthSession?>

    suspend fun save(session: AuthSession)

    suspend fun clear()
}
