package com.redcode.im.androidapp.data.media

data class CachedAvatar(
    val objectKey: String,
    val localPath: String,
    val size: Long,
)

class AvatarCacheRepository(
    private val remoteDataSource: AvatarRemoteDataSource,
    private val cache: FileResourceCache,
) {
    suspend fun loadCurrentUserAvatar(
        userId: String,
        objectKey: String?,
        token: String,
        forceRefresh: Boolean = false,
    ): CachedAvatar? =
        loadAvatar(
            objectKey = objectKey,
            token = token,
            forceRefresh = forceRefresh,
            downloadUrl = { remoteDataSource.fetchCurrentUserAvatarDownloadUrl(token = token) },
        )

    suspend fun loadUserAvatar(
        userId: String,
        objectKey: String?,
        token: String,
        forceRefresh: Boolean = false,
    ): CachedAvatar? =
        loadAvatar(
            objectKey = objectKey,
            token = token,
            forceRefresh = forceRefresh,
            downloadUrl = { remoteDataSource.fetchUserAvatarDownloadUrl(userId = userId, token = token) },
        )

    suspend fun loadRoomAvatar(
        roomId: String,
        objectKey: String?,
        token: String,
        forceRefresh: Boolean = false,
    ): CachedAvatar? =
        loadAvatar(
            objectKey = objectKey,
            token = token,
            forceRefresh = forceRefresh,
            downloadUrl = { remoteDataSource.fetchRoomAvatarDownloadUrl(roomId = roomId, token = token) },
        )

    suspend fun clear() {
        cache.clear()
    }

    private suspend fun loadAvatar(
        objectKey: String?,
        token: String,
        forceRefresh: Boolean,
        downloadUrl: suspend () -> String?,
    ): CachedAvatar? {
        val key = objectKey?.trim()?.takeIf { it.isNotBlank() } ?: return null
        if (token.isBlank()) return null
        if (!forceRefresh) {
            cache.get(key)?.let { return it.toAvatar() }
        }
        return runCatching {
            val url = downloadUrl()?.takeIf { it.isNotBlank() } ?: return null
            val bytes = remoteDataSource.downloadBytes(url)
            cache.put(key = key, bytes = bytes).toAvatar()
        }.getOrNull()
    }

    private fun CachedFileResource.toAvatar(): CachedAvatar =
        CachedAvatar(objectKey = key, localPath = localPath, size = size)
}
