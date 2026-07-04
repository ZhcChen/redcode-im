package com.redcode.im.androidapp.data.settings

import com.redcode.im.androidapp.core.model.AppSettings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemorySettingsRepository : SettingsRepository {
    private val state = MutableStateFlow(AppSettings())
    override val settings = state.asStateFlow()

    override suspend fun setNotificationEnabled(enabled: Boolean) {
        state.value = state.value.copy(notificationEnabled = enabled)
    }
}
