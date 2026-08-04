package com.redcode.im.androidapp.data.media

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AvatarDownloadUrlResponse(
    val success: Boolean = true,
    val message: String = "",
    @SerialName("download_url")
    val downloadUrl: String? = null,
)
