package com.redcode.im.androidapp.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.data.settings.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SettingsDocumentUiState(
    val kind: SettingsDocumentKind? = null,
    val isLoading: Boolean = false,
    val document: DocumentContent? = null,
    val errorMessage: String? = null,
)

class SettingsViewModel(
    private val settingsRepository: SettingsRepository,
) : ViewModel() {
    val settings: StateFlow<AppSettings> = settingsRepository.settings
    private val documentState = MutableStateFlow(SettingsDocumentUiState())
    val document = documentState.asStateFlow()

    fun toggleNotification() {
        viewModelScope.launch {
            settingsRepository.setNotificationEnabled(!settings.value.notificationEnabled)
        }
    }

    fun loadDocument(kind: SettingsDocumentKind) {
        documentState.value = SettingsDocumentUiState(kind = kind, isLoading = true)
        viewModelScope.launch {
            runCatching {
                settingsRepository.fetchDocument(kind)
            }.onSuccess { loaded ->
                documentState.value = SettingsDocumentUiState(kind = kind, document = loaded)
            }.onFailure { error ->
                documentState.value =
                    SettingsDocumentUiState(
                        kind = kind,
                        errorMessage = error.message ?: "${kind.title}加载失败",
                    )
            }
        }
    }

    fun dismissDocument() {
        documentState.value = SettingsDocumentUiState()
    }
}
