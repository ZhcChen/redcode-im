package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.e2ee.E2eeRoomEventHandling

class E2eeAwareRoomRepository(
    private val delegate: RoomRepository,
    private val e2eeEvents: E2eeRoomEventHandling,
) : RoomRepository by delegate {
    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>) =
        delegate.createGroup(name, description, memberIds).also { room ->
            e2eeEvents.reconcile(room.id)
        }

    override suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult =
        delegate.addMembers(roomId, userIds).also {
            e2eeEvents.reconcile(roomId)
        }

    override suspend fun removeMember(roomId: String, userId: String) {
        delegate.removeMember(roomId, userId)
        e2eeEvents.reconcile(roomId)
    }
}
