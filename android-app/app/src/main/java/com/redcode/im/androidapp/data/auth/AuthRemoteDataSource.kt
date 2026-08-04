package com.redcode.im.androidapp.data.auth

interface AuthRemoteDataSource {
    suspend fun register(username: String, password: String, nickname: String): BackendAuthUser

    suspend fun login(username: String, password: String): BackendAuthSession

    suspend fun me(token: String): BackendAuthUser

    suspend fun refresh(refreshToken: String): BackendAuthSession
}
