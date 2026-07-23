package com.redcode.im.androidapp.data.emoji

import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.network.APIClient

interface EmojiRemoteDataSource {
    suspend fun fetchMyPacks(token: String): List<StickerPack>

    suspend fun fetchDownloadUrl(objectKey: String, token: String, expiresInSeconds: Int = 3_600): String?

    suspend fun downloadBytes(url: String, maxBytes: Long = MAX_STICKER_DOWNLOAD_BYTES): ByteArray

    companion object {
        const val MAX_STICKER_DOWNLOAD_BYTES: Long = 2 * 1024 * 1024
    }
}

class HttpEmojiRemoteDataSource(
    private val apiClient: APIClient,
) : EmojiRemoteDataSource {
    override suspend fun fetchMyPacks(token: String): List<StickerPack> =
        apiClient
            .get<List<BackendEmojiPackWithItems>>(EmojiAPIEndpoint.myPacks, bearerToken = token)
            .map { it.toDomain() }

    override suspend fun fetchDownloadUrl(objectKey: String, token: String, expiresInSeconds: Int): String? =
        apiClient
            .get<EmojiDownloadUrlResponse>(
                EmojiAPIEndpoint.downloadUrl(objectKey = objectKey, expiresInSeconds = expiresInSeconds),
                bearerToken = token,
            )
            .takeIf { it.success }
            ?.downloadUrl
            ?.takeIf { it.isNotBlank() }

    override suspend fun downloadBytes(url: String, maxBytes: Long): ByteArray {
        return apiClient.downloadBytes(url, maxBytes = maxBytes)
    }
}
