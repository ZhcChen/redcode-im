package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.e2ee.E2eeDeviceInfo
import com.redcode.im.androidapp.e2ee.E2eeDeviceManaging
import com.redcode.im.androidapp.e2ee.E2eeRoomEventHandling
import com.redcode.im.androidapp.e2ee.E2eeSessionStateController
import com.redcode.im.androidapp.e2ee.E2eeSessionStatus
import com.redcode.im.androidapp.feature.settings.E2eeDeviceManagementViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class E2eeDeviceManagementViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun approveRefreshesDeviceListWithoutPrematureReconcile() = runTest {
        val fixture = Fixture()
        val pending = fixture.devices.items.last()
        val viewModel = fixture.viewModel()

        viewModel.refresh()
        advanceUntilIdle()
        viewModel.approve(pending)
        advanceUntilIdle()

        assertEquals(listOf(pending.id), fixture.devices.approved)
        assertEquals(emptyList<String>(), fixture.roomEvents.rooms)
        assertEquals("active", viewModel.uiState.value.devices.first { it.id == pending.id }.status)
    }

    @Test
    fun revokingOtherDeviceReconcilesEveryCurrentRoom() = runTest {
        val fixture = Fixture()
        val other = fixture.devices.items.first { it.id == "device-other" }
        val viewModel = fixture.viewModel()

        viewModel.revoke(other)
        advanceUntilIdle()

        assertEquals(listOf(other.id), fixture.devices.revoked)
        assertEquals(listOf("room-1", "room-2"), fixture.roomEvents.rooms)
        assertEquals(1, fixture.rooms.refreshCalls)
        assertEquals(0, fixture.lifecycle.foregroundCalls)
    }

    @Test
    fun revokingCurrentDeviceRefreshesLifecycleAndDoesNotAttemptRoomCommit() = runTest {
        val fixture = Fixture()
        val current = fixture.devices.items.first { it.id == "device-current" }
        val viewModel = fixture.viewModel()

        viewModel.revoke(current)
        advanceUntilIdle()

        assertEquals(1, fixture.lifecycle.foregroundCalls)
        assertEquals(emptyList<String>(), fixture.roomEvents.rooms)
    }

    @Test
    fun currentDeviceRevocationFailsClosedWhenLifecycleRemainsReady() = runTest {
        val fixture = Fixture()
        fixture.lifecycle.blockOnForeground = false
        val current = fixture.devices.items.first { it.id == "device-current" }
        val viewModel = fixture.viewModel()

        viewModel.revoke(current)
        advanceUntilIdle()

        assertEquals("当前 E2EE 设备撤销后仍处于 Ready 状态", viewModel.uiState.value.errorMessage)
        assertEquals(emptyList<String>(), fixture.roomEvents.rooms)
    }
}

private class Fixture {
    val devices = RecordingDeviceManager()
    val lifecycle = RecordingSessionController()
    val rooms = RecordingRooms()
    val roomEvents = RecordingDeviceRoomEvents()

    fun viewModel() = E2eeDeviceManagementViewModel(
        accountId = "account-a",
        token = "token",
        devices = devices,
        lifecycle = lifecycle,
        rooms = rooms,
        roomEvents = roomEvents,
    )
}

private class RecordingDeviceManager : E2eeDeviceManaging {
    var items = listOf(
        E2eeDeviceInfo("device-current", "Current", 1, "fingerprint", "active"),
        E2eeDeviceInfo("device-other", "Other", 1, "fingerprint", "active"),
        E2eeDeviceInfo("device-pending", "Pending", 1, "fingerprint", "pending_approval"),
    )
    val approved = mutableListOf<String>()
    val revoked = mutableListOf<String>()
    override suspend fun listDevices(token: String) = items
    override suspend fun approveDevice(accountId: String, target: E2eeDeviceInfo, token: String): E2eeDeviceInfo {
        approved += target.id
        val updated = target.copy(status = "active")
        items = items.map { if (it.id == target.id) updated else it }
        return updated
    }
    override suspend fun revokeDevice(deviceId: String, token: String): E2eeDeviceInfo {
        revoked += deviceId
        val updated = items.first { it.id == deviceId }.copy(status = "revoked")
        items = items.map { if (it.id == deviceId) updated else it }
        return updated
    }
}

private class RecordingSessionController : E2eeSessionStateController {
    override val status = MutableStateFlow<E2eeSessionStatus>(E2eeSessionStatus.Ready("account-a", "device-current"))
    var foregroundCalls = 0
    var blockOnForeground = true
    override suspend fun onForeground() {
        foregroundCalls += 1
        if (blockOnForeground) status.value = E2eeSessionStatus.Blocked("设备已撤销")
    }
}

private class RecordingRooms : RoomRepository {
    override val rooms: Flow<List<RoomInfo>> = MutableStateFlow(listOf(RoomInfo("room-1", "One"), RoomInfo("room-2", "Two")))
    var refreshCalls = 0
    override suspend fun refreshRooms() { refreshCalls += 1 }
    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>) = error("unused")
    override suspend fun getRoom(roomId: String): RoomInfo? = null
    override suspend fun updateRoom(roomId: String, name: String?, description: String?) = error("unused")
    override suspend fun dissolveRoom(roomId: String) = Unit
    override suspend fun leaveRoom(roomId: String) = Unit
}

private class RecordingDeviceRoomEvents : E2eeRoomEventHandling {
    val rooms = mutableListOf<String>()
    override suspend fun reconcile(roomId: String) { rooms += roomId }
}
