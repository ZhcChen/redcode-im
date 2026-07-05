package com.redcode.im.androidapp.data.settings

import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemorySettingsRepository(
    private val documents: Map<SettingsDocumentKind, DocumentContent> = DEFAULT_DOCUMENTS,
) : SettingsRepository {
    private val state = MutableStateFlow(AppSettings())
    override val settings = state.asStateFlow()

    override suspend fun setNotificationEnabled(enabled: Boolean) {
        state.value = state.value.copy(notificationEnabled = enabled)
    }

    override suspend fun fetchDocument(kind: SettingsDocumentKind): DocumentContent =
        documents.getValue(kind)

    companion object {
        private val DEFAULT_DOCUMENTS =
            mapOf(
                SettingsDocumentKind.UserAgreement to
                    DocumentContent(
                        title = "用户协议",
                        content = "使用 RedCode IM 即表示你同意本用户协议。本地开发阶段展示 mock 文档，真实联调时来自后端公开配置。",
                    ),
                SettingsDocumentKind.PrivacyPolicy to
                    DocumentContent(
                        title = "隐私协议",
                        content = "RedCode IM 尊重并保护你的隐私。本地开发阶段展示 mock 文档，真实联调时来自后端公开配置。",
                    ),
            )
    }
}
