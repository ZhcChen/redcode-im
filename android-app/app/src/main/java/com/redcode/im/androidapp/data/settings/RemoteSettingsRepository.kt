package com.redcode.im.androidapp.data.settings

import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.GeneralSettings
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.network.APIClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class RemoteSettingsRepository(
    private val apiClient: APIClient,
) : SettingsRepository {
    private val state = MutableStateFlow(AppSettings())
    override val settings = state.asStateFlow()

    override suspend fun refreshGeneralSettings(): AppSettings {
        val general = apiClient.get<GeneralSettings>(SettingsAPIEndpoint.general())
        return state.value.copy(appName = general.appName, messageRuntime = general.messageRuntime).also { state.value = it }
    }

    override suspend fun setNotificationEnabled(enabled: Boolean) {
        state.value = state.value.copy(notificationEnabled = enabled)
    }

    override suspend fun fetchDocument(kind: SettingsDocumentKind): DocumentContent =
        apiClient.get(SettingsAPIEndpoint.document(kind))
}
