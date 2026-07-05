package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import kotlinx.serialization.Serializable

@Serializable
data class AuthSessionSnapshot(
    val userId: String,
    val accountName: String,
    val displayName: String,
    val avatarUrl: String? = null,
    val accessToken: String,
    val refreshToken: String,
) {
    fun toDomain(): AuthSession =
        AuthSession(
            user =
                AuthUser(
                    id = userId,
                    accountName = accountName,
                    displayName = displayName,
                    avatarUrl = avatarUrl,
                ),
            tokens =
                TokenPair(
                    accessToken = accessToken,
                    refreshToken = refreshToken,
                ),
        )

    companion object {
        fun fromDomain(session: AuthSession): AuthSessionSnapshot =
            AuthSessionSnapshot(
                userId = session.user.id,
                accountName = session.user.accountName,
                displayName = session.user.displayName,
                avatarUrl = session.user.avatarUrl,
                accessToken = session.tokens.accessToken,
                refreshToken = session.tokens.refreshToken,
            )
    }
}
