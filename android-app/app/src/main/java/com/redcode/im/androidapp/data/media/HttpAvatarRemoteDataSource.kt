package com.redcode.im.androidapp.data.media

import com.redcode.im.androidapp.network.APIClient

class HttpAvatarRemoteDataSource(
    private val apiClient: APIClient,
) : AvatarRemoteDataSource {
    override suspend fun fetchCurrentUserAvatarDownloadUrl(token: String, expiresInSeconds: Int): String? =
        fetchDownloadUrl(AvatarAPIEndpoint.currentUserAvatarDownloadUrl(expiresInSeconds), token)

    override suspend fun fetchUserAvatarDownloadUrl(userId: String, token: String, expiresInSeconds: Int): String? =
        fetchDownloadUrl(AvatarAPIEndpoint.userAvatarDownloadUrl(userId, expiresInSeconds), token)

    override suspend fun fetchRoomAvatarDownloadUrl(roomId: String, token: String, expiresInSeconds: Int): String? =
        fetchDownloadUrl(AvatarAPIEndpoint.roomAvatarDownloadUrl(roomId, expiresInSeconds), token)

    override suspend fun downloadBytes(url: String): ByteArray =
        apiClient.downloadBytes(url)

    private suspend fun fetchDownloadUrl(endpoint: com.redcode.im.androidapp.network.APIEndpoint, token: String): String? {
        val response = apiClient.get<AvatarDownloadUrlResponse>(endpoint, bearerToken = token)
        return response.downloadUrl?.takeIf { response.success && it.isNotBlank() }
    }
}
