package com.redcode.im.androidapp.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

data class AppSettings(
    val appName: String = "RedCode IM",
    val notificationEnabled: Boolean = true,
    val darkModeEnabled: Boolean = false,
    val chatBackground: String? = null,
    val messageRuntime: MessageRuntimeSettings = MessageRuntimeSettings(),
)

@Serializable
data class MessageRuntimeSettings(
    @SerialName("server_storage_mode")
    val serverStorageMode: String = "persist",
    @SerialName("content_audit_mode")
    val contentAuditMode: String = "plaintext",
    @SerialName("updated_at")
    val updatedAt: String? = null,
    @SerialName("updated_by")
    val updatedBy: String? = null,
) {
    val isE2ee: Boolean
        get() = contentAuditMode == "e2ee"

    fun requireSupported(): MessageRuntimeSettings {
        require(serverStorageMode in SUPPORTED_STORAGE_MODES) { "未知的消息存储模式：$serverStorageMode" }
        require(contentAuditMode in SUPPORTED_AUDIT_MODES) { "未知的消息审计模式：$contentAuditMode" }
        return this
    }

    private companion object {
        val SUPPORTED_STORAGE_MODES = setOf("persist", "relay_only")
        val SUPPORTED_AUDIT_MODES = setOf("plaintext", "e2ee")
    }
}

@Serializable
data class GeneralSettings(
    @SerialName("app_name")
    val appName: String = "RedCode IM",
    @SerialName("message_runtime")
    val messageRuntime: MessageRuntimeSettings = MessageRuntimeSettings(),
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
