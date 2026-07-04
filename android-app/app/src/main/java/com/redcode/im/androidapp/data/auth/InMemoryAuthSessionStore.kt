package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemoryAuthSessionStore(initialSession: AuthSession? = null) : AuthSessionStore {
    private val state = MutableStateFlow(initialSession)
    override val session = state.asStateFlow()

    override suspend fun save(session: AuthSession) {
        state.value = session
    }

    override suspend fun clear() {
        state.value = null
    }
}
