package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage

internal fun ChatMessage.withAttachmentLocalPath(key: String, localPath: String): ChatMessage =
    copy(
        parts =
            parts.map { part ->
                val attachment = part.attachment
                if (attachment?.key == key) {
                    part.copy(attachment = attachment.copy(localPath = localPath))
                } else {
                    part
                }
            },
    )

internal fun ChatMessage.withAttachmentLocalPathsFrom(source: ChatMessage?): ChatMessage {
    if (source == null) return this
    val localPathsByKey =
        source.parts
            .mapNotNull { it.attachment }
            .mapNotNull { attachment ->
                val localPath = attachment.localPath?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
                attachment.key to localPath
            }
            .toMap()
    if (localPathsByKey.isEmpty()) return this
    return copy(
        parts =
            parts.map { part ->
                val attachment = part.attachment
                val localPath = attachment?.key?.let(localPathsByKey::get)
                if (attachment != null && localPath != null) {
                    part.copy(attachment = attachment.copy(localPath = localPath))
                } else {
                    part
                }
            },
    )
}
