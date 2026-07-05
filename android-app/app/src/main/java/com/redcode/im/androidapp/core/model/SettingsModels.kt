package com.redcode.im.androidapp.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

data class AppSettings(
    val appName: String = "RedCode IM",
    val notificationEnabled: Boolean = true,
    val darkModeEnabled: Boolean = false,
    val chatBackground: String? = null,
)

enum class SettingsDocumentKind(val title: String) {
    PrivacyPolicy("隐私协议"),
    UserAgreement("用户协议"),
}

@Serializable
data class DocumentContent(
    val title: String,
    val content: String,
    @SerialName("updated_at")
    val updatedAt: String? = null,
)
