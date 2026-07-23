package com.redcode.im.androidapp.data.emoji

import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BackendEmojiPackWithItems(
    val pack: BackendEmojiPack,
    val items: List<BackendEmojiItem> = emptyList(),
) {
    fun toDomain(): StickerPack =
        StickerPack(
            id = pack.id,
            name = pack.name,
            items =
                items
                    .sortedBy { it.sortOrder }
                    .map { item ->
                        StickerItem(
                            id = item.id,
                            label = item.name?.takeIf { it.isNotBlank() } ?: pack.name,
                            imageObjectKey = item.imageObjectKey?.takeIf { it.isNotBlank() },
                            imageUrl = item.imageUrl.takeIf { it.isNotBlank() },
                            mime = item.mime(),
                        )
                    },
        )
}

@Serializable
data class BackendEmojiPack(
    val id: String,
    val name: String,
    @SerialName("icon_url")
    val iconUrl: String? = null,
    @SerialName("icon_object_key")
    val iconObjectKey: String? = null,
    val description: String? = null,
)

@Serializable
data class BackendEmojiItem(
    val id: String,
    @SerialName("pack_id")
    val packId: String,
    @SerialName("image_url")
    val imageUrl: String,
    @SerialName("image_object_key")
    val imageObjectKey: String? = null,
    val name: String? = null,
    @SerialName("sort_order")
    val sortOrder: Int = 0,
) {
    fun mime(): String =
        when {
            imageUrl.endsWith(".png", ignoreCase = true) || imageObjectKey?.endsWith(".png", ignoreCase = true) == true -> "image/png"
            imageUrl.endsWith(".jpg", ignoreCase = true) || imageUrl.endsWith(".jpeg", ignoreCase = true) ||
                imageObjectKey?.endsWith(".jpg", ignoreCase = true) == true ||
                imageObjectKey?.endsWith(".jpeg", ignoreCase = true) == true -> "image/jpeg"
            imageUrl.endsWith(".webp", ignoreCase = true) || imageObjectKey?.endsWith(".webp", ignoreCase = true) == true -> "image/webp"
            else -> "image/gif"
        }
}

@Serializable
data class EmojiDownloadUrlResponse(
    val success: Boolean = false,
    val message: String = "",
    @SerialName("download_url")
    val downloadUrl: String? = null,
)
