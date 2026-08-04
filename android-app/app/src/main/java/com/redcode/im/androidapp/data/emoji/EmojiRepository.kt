package com.redcode.im.androidapp.data.emoji

import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.core.model.attachmentFileName
import com.redcode.im.androidapp.core.model.redCodeDefaultStickerPacks
import com.redcode.im.androidapp.data.media.FileResourceCache
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext

interface EmojiRepository {
    suspend fun loadStickerPacks(): List<StickerPack>

    suspend fun prepareStickerUpload(sticker: StickerItem): AttachmentUploadPayload?

    suspend fun clearLocalState() = Unit
}

class InMemoryEmojiRepository(
    private val packs: List<StickerPack> = redCodeDefaultStickerPacks,
) : EmojiRepository {
    override suspend fun loadStickerPacks(): List<StickerPack> =
        packs

    override suspend fun prepareStickerUpload(sticker: StickerItem): AttachmentUploadPayload? =
        null
}

class RemoteEmojiRepository(
    private val remoteDataSource: EmojiRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val cache: FileResourceCache,
) : EmojiRepository {
    override suspend fun loadStickerPacks(): List<StickerPack> {
        val token = token()
        val packs = remoteDataSource.fetchMyPacks(token).filter { it.items.isNotEmpty() }
        return packs.ifEmpty { redCodeDefaultStickerPacks }
    }

    override suspend fun prepareStickerUpload(sticker: StickerItem): AttachmentUploadPayload? {
        val source = sticker.imageObjectKey?.takeIf { it.isNotBlank() } ?: return null
        val cached =
            cache.getOrPut(key = source) {
                val downloadUrl =
                    remoteDataSource.fetchDownloadUrl(objectKey = source, token = token())
                        ?: error("贴纸下载地址不可用")
                remoteDataSource.downloadBytes(downloadUrl)
            }
        val bytes = withContext(Dispatchers.IO) { File(cached.localPath).readBytes() }
        return AttachmentUploadPayload(
            bytes = bytes,
            fileName = sticker.attachmentFileName(),
            mime = sticker.mime,
        )
    }

    override suspend fun clearLocalState() {
        cache.clear()
    }

    private fun token(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() } ?: error("请先登录后再加载表情")
}
