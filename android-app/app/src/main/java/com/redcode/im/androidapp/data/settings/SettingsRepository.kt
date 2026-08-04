package com.redcode.im.androidapp.data.settings

import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import kotlinx.coroutines.flow.StateFlow

interface SettingsRepository {
    val settings: StateFlow<AppSettings>

    suspend fun setNotificationEnabled(enabled: Boolean)

    suspend fun fetchDocument(kind: SettingsDocumentKind): DocumentContent
}
