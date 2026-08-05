package com.redcode.im.androidapp.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.e2ee.E2eeDeviceInfo
import com.redcode.im.androidapp.e2ee.E2eeDeviceManaging
import com.redcode.im.androidapp.e2ee.E2eeRoomEventHandling
import com.redcode.im.androidapp.e2ee.E2eeSessionStateController
import com.redcode.im.androidapp.e2ee.E2eeSessionStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class E2eeDeviceManagementUiState(
    val devices: List<E2eeDeviceInfo> = emptyList(),
    val currentDeviceId: String? = null,
    val isE2eeRuntime: Boolean = false,
    val isLoading: Boolean = false,
    val operatingDeviceId: String? = null,
    val errorMessage: String? = null,
)

class E2eeDeviceManagementViewModel(
    private val accountId: String,
    private val token: String,
    private val devices: E2eeDeviceManaging,
    private val lifecycle: E2eeSessionStateController,
    private val rooms: RoomRepository,
    private val roomEvents: E2eeRoomEventHandling,
) : ViewModel() {
    private val mutableUiState = MutableStateFlow(E2eeDeviceManagementUiState())
    val uiState: StateFlow<E2eeDeviceManagementUiState> = mutableUiState.asStateFlow()

    fun refresh() {
        viewModelScope.launch { refreshNow() }
    }

    fun approve(device: E2eeDeviceInfo) {
        operate(device.id) {
            devices.approveDevice(accountId, device, token)
        }
    }

    fun revoke(device: E2eeDeviceInfo) {
        operate(device.id) {
            devices.revokeDevice(device.id, token)
            val currentDeviceId = (lifecycle.status.value as? E2eeSessionStatus.Ready)?.deviceId
            if (device.id == currentDeviceId) {
                val refreshFailure = runCatching { lifecycle.onForeground() }.exceptionOrNull()
                if (lifecycle.status.value is E2eeSessionStatus.Ready) {
                    throw refreshFailure ?: IllegalStateException("当前 E2EE 设备撤销后仍处于 Ready 状态")
                }
            } else {
                rooms.refreshRooms()
                rooms.rooms.first().forEach { room -> roomEvents.reconcile(room.id) }
            }
        }
    }

    private fun operate(deviceId: String, operation: suspend () -> Unit) {
        viewModelScope.launch {
            mutableUiState.value = mutableUiState.value.copy(operatingDeviceId = deviceId, errorMessage = null)
            val operationError = runCatching { operation() }.exceptionOrNull()
            refreshNow()
            mutableUiState.value = mutableUiState.value.copy(
                operatingDeviceId = null,
                errorMessage = operationError?.message ?: mutableUiState.value.errorMessage,
            )
        }
    }

    private suspend fun refreshNow() {
        val status = lifecycle.status.value
        if (status == E2eeSessionStatus.Plaintext || status == E2eeSessionStatus.SignedOut) {
            mutableUiState.value = E2eeDeviceManagementUiState(isE2eeRuntime = false)
            return
        }
        mutableUiState.value = mutableUiState.value.copy(isE2eeRuntime = true, isLoading = true, errorMessage = null)
        runCatching { devices.listDevices(token) }
            .onSuccess { loaded ->
                mutableUiState.value = mutableUiState.value.copy(
                    devices = loaded.sortedWith(compareBy<E2eeDeviceInfo> { it.status != "pending_approval" }.thenBy { it.deviceLabel }),
                    currentDeviceId = (lifecycle.status.value as? E2eeSessionStatus.Ready)?.deviceId,
                    isLoading = false,
                )
            }
            .onFailure { error ->
                mutableUiState.value = mutableUiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: "加载 E2EE 设备失败",
                )
            }
    }
}
