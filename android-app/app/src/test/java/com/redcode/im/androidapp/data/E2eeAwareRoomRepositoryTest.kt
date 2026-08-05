package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.data.rooms.E2eeAwareRoomRepository
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.e2ee.E2eeRoomEventHandling
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class E2eeAwareRoomRepositoryTest {
    @Test
    fun successfulMembershipMutationsReconcileAffectedRoom() = runTest {
        val delegate = RecordingRoomRepository()
        val events = RecordingRoomEvents()
        val repository = E2eeAwareRoomRepository(delegate, events)

        repository.createGroup("Group", null, listOf("user-b"))
        repository.addMembers("room-1", listOf("user-c"))
        repository.removeMember("room-1", "user-c")

        assertEquals(listOf("room-1", "room-1", "room-1"), events.rooms)
        assertEquals(listOf("create", "add", "remove"), delegate.calls)
    }
}

private class RecordingRoomEvents : E2eeRoomEventHandling {
    val rooms = mutableListOf<String>()
    override suspend fun reconcile(roomId: String) { rooms += roomId }
}

private class RecordingRoomRepository : RoomRepository {
    val calls = mutableListOf<String>()
    override val rooms: Flow<List<RoomInfo>> = flowOf(emptyList())

    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>): RoomInfo {
        calls += "create"
        return RoomInfo(id = "room-1", name = name, roomType = "group")
    }

    override suspend fun getRoom(roomId: String): RoomInfo? = null
    override suspend fun updateRoom(roomId: String, name: String?, description: String?): RoomInfo =
        error("unused")
    override suspend fun dissolveRoom(roomId: String) = Unit
    override suspend fun leaveRoom(roomId: String) = Unit

    override suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult {
        calls += "add"
        return AddMembersResult(userIds, emptyList())
    }

    override suspend fun removeMember(roomId: String, userId: String) {
        calls += "remove"
    }
}
