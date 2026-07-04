package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.network.APIClient

class HttpAuthRemoteDataSource(
    private val apiClient: APIClient,
) : AuthRemoteDataSource {
    override suspend fun register(username: String, password: String, nickname: String): BackendAuthUser =
        apiClient.post<AccountRegistrationRequest, BackendAuthUser>(
            AuthAPIEndpoint.register,
            AccountRegistrationRequest(username = username, password = password, nickname = nickname),
        )

    override suspend fun login(username: String, password: String): BackendAuthSession =
        apiClient.post<AccountLoginRequest, BackendAuthSession>(
            AuthAPIEndpoint.login,
            AccountLoginRequest(username = username, password = password),
        )

    override suspend fun me(token: String): BackendAuthUser =
        apiClient.get(AuthAPIEndpoint.me, bearerToken = token)

    override suspend fun refresh(refreshToken: String): BackendAuthSession =
        apiClient.post<RefreshTokenRequest, BackendAuthSession>(
            AuthAPIEndpoint.refresh,
            RefreshTokenRequest(refreshToken = refreshToken),
        )
}
