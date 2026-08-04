package com.redcode.im.androidapp.ui.components

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.redcode.im.androidapp.data.media.AvatarCacheRepository

enum class CachedAvatarKind {
    CurrentUser,
    User,
    Room,
}

@Composable
fun CachedAvatarBadge(
    kind: CachedAvatarKind,
    entityId: String?,
    objectKey: String?,
    label: String,
    token: String,
    avatarCacheRepository: AvatarCacheRepository?,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
) {
    var localPath by remember { mutableStateOf<String?>(null) }
    val normalizedObjectKey = objectKey?.takeIf { it.isNotBlank() }
    val normalizedEntityId = entityId?.takeIf { it.isNotBlank() }

    LaunchedEffect(kind, normalizedEntityId, normalizedObjectKey, token, avatarCacheRepository) {
        localPath = null
        val repository = avatarCacheRepository ?: return@LaunchedEffect
        val key = normalizedObjectKey ?: return@LaunchedEffect
        val id = normalizedEntityId ?: return@LaunchedEffect
        val cached =
            when (kind) {
                CachedAvatarKind.CurrentUser -> repository.loadCurrentUserAvatar(userId = id, objectKey = key, token = token)
                CachedAvatarKind.User -> repository.loadUserAvatar(userId = id, objectKey = key, token = token)
                CachedAvatarKind.Room -> repository.loadRoomAvatar(roomId = id, objectKey = key, token = token)
            }
        localPath = cached?.localPath
    }

    val imageBitmap =
        remember(localPath) {
            localPath
                ?.let { path -> runCatching { BitmapFactory.decodeFile(path)?.asImageBitmap() }.getOrNull() }
        }
    val initial = label.trim().take(1).uppercase().ifBlank { "R" }

    Box(
        modifier =
            modifier
                .size(size)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer)
                .testTag("cached-avatar-${kind.name.lowercase()}-${normalizedEntityId.orEmpty()}"),
        contentAlignment = Alignment.Center,
    ) {
        if (imageBitmap != null) {
            Image(
                bitmap = imageBitmap,
                contentDescription = label.ifBlank { "avatar" },
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Text(
                text = initial,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}
