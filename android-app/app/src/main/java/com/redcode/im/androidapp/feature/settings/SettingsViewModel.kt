package com.redcode.im.androidapp.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.data.settings.SettingsRepository
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class SettingsViewModel(
    private val settingsRepository: SettingsRepository,
) : ViewModel() {
    val settings: StateFlow<AppSettings> = settingsRepository.settings

    fun toggleNotification() {
        viewModelScope.launch {
            settingsRepository.setNotificationEnabled(!settings.value.notificationEnabled)
        }
    }
}
