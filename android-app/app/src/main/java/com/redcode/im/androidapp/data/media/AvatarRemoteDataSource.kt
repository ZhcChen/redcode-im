package com.redcode.im.androidapp.data.media

interface AvatarRemoteDataSource {
    suspend fun fetchCurrentUserAvatarDownloadUrl(token: String, expiresInSeconds: Int = 3_600): String?

    suspend fun fetchUserAvatarDownloadUrl(userId: String, token: String, expiresInSeconds: Int = 3_600): String?

    suspend fun fetchRoomAvatarDownloadUrl(roomId: String, token: String, expiresInSeconds: Int = 3_600): String?

    suspend fun downloadBytes(url: String): ByteArray
}
