package com.redcode.im.androidapp.core.model

import kotlinx.serialization.Serializable

@Serializable
data class ChatRoomPreferences(
    val backgroundKey: String = DEFAULT_BACKGROUND_KEY,
    val fontScale: Float = DEFAULT_FONT_SCALE,
    val enterToSend: Boolean = false,
    val autoDownloadMedia: Boolean = false,
) {
    fun normalized(): ChatRoomPreferences =
        copy(
            backgroundKey = backgroundKey.takeIf { key -> chatBackgroundOptions.any { it.key == key } } ?: DEFAULT_BACKGROUND_KEY,
            fontScale = fontScale.coerceIn(MIN_FONT_SCALE, MAX_FONT_SCALE),
        )

    companion object {
        const val DEFAULT_BACKGROUND_KEY = "default"
        const val DEFAULT_FONT_SCALE = 1.0f
        const val MIN_FONT_SCALE = 0.85f
        const val MAX_FONT_SCALE = 1.3f
    }
}

data class ChatBackgroundOption(
    val key: String,
    val label: String,
    val colorArgb: Int? = null,
)

val chatBackgroundOptions: List<ChatBackgroundOption> =
    listOf(
        ChatBackgroundOption(ChatRoomPreferences.DEFAULT_BACKGROUND_KEY, "默认"),
        ChatBackgroundOption("warm", "暖色", 0xFFFFF3E0.toInt()),
        ChatBackgroundOption("blue", "蓝色", 0xFFE3F2FD.toInt()),
        ChatBackgroundOption("mint", "薄荷", 0xFFE0F2F1.toInt()),
    )

data class StickerItem(
    val id: String,
    val label: String,
    val imageObjectKey: String? = null,
    val imageUrl: String? = null,
    val mime: String = "image/gif",
)

data class StickerPack(
    val id: String,
    val name: String,
    val items: List<StickerItem>,
)

val redCodeBuiltInEmoji: List<String> =
    listOf(
        "😀", "😄", "😂", "😊", "😍", "😘", "😎", "😭",
        "😡", "👍", "👎", "🙏", "👏", "💪", "🎉", "❤️",
        "🔥", "✨", "✅", "❌", "👀", "🤝", "💯", "🍻",
    )

val redCodeDefaultStickerPacks: List<StickerPack> =
    listOf(
        StickerPack(
            id = "redcode-default",
            name = "RedCode 默认",
            items =
                listOf(
                    StickerItem(id = "redcode-ok", label = "OK", imageObjectKey = "emoji-items/redcode-ok.gif"),
                    StickerItem(id = "redcode-fire", label = "火力", imageObjectKey = "emoji-items/redcode-fire.gif"),
                    StickerItem(id = "redcode-cheers", label = "干杯", imageObjectKey = "emoji-items/redcode-cheers.gif"),
                ),
        ),
    )

fun StickerItem.attachmentFileName(): String {
    val keyName = imageObjectKey?.fileNameSegment()
    if (!keyName.isNullOrBlank()) return keyName
    val urlName = imageUrl?.substringBefore('?')?.fileNameSegment()
    if (!urlName.isNullOrBlank()) return urlName
    val safeLabel =
        label
            .lowercase()
            .map { if (it.isLetterOrDigit()) it else '-' }
            .joinToString("")
            .trim('-')
            .ifBlank { id.ifBlank { "sticker" } }
    return "$safeLabel.${mime.defaultImageExtension()}"
}

private fun String.fileNameSegment(): String? =
    substringAfterLast('/').takeIf { it.contains('.') && it.substringAfterLast('.').isNotBlank() }

private fun String.defaultImageExtension(): String =
    when (lowercase()) {
        "image/png" -> "png"
        "image/jpeg" -> "jpg"
        "image/webp" -> "webp"
        else -> "gif"
    }
