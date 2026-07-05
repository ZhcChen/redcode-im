package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AccountRegistrationRequest(
    val username: String,
    val password: String,
    val nickname: String,
)

@Serializable
data class AccountLoginRequest(
    val username: String,
    val password: String,
)

@Serializable
data class RefreshTokenRequest(
    @SerialName("refresh_token")
    val refreshToken: String,
)

@Serializable
data class BackendAuthUser(
    val id: String,
    val username: String? = null,
    val email: String? = null,
    val nickname: String? = null,
    val status: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("avatar_object_key")
    val avatarObjectKey: String? = null,
) {
    fun toDomain(): AuthUser {
        val account = username ?: email ?: id
        return AuthUser(
            id = id,
            accountName = account,
            displayName = nickname?.takeIf { it.isNotBlank() } ?: account,
            avatarUrl = avatarUrl,
            avatarObjectKey = avatarObjectKey,
        )
    }
}

@Serializable
data class BackendAuthSession(
    val token: String,
    @SerialName("refresh_token")
    val refreshToken: String? = null,
    val user: BackendAuthUser,
) {
    fun toDomain(): AuthSession =
        AuthSession(
            user = user.toDomain(),
            tokens =
                TokenPair(
                    accessToken = token,
                    refreshToken = refreshToken.orEmpty(),
                ),
        )
}
