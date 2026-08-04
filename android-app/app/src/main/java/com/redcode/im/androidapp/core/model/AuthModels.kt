package com.redcode.im.androidapp.core.model

data class AuthUser(
    val id: String,
    val accountName: String,
    val displayName: String,
    val avatarUrl: String? = null,
    val avatarObjectKey: String? = null,
)

data class TokenPair(
    val accessToken: String,
    val refreshToken: String,
)

data class AuthSession(
    val user: AuthUser,
    val tokens: TokenPair,
)
