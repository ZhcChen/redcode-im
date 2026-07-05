package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import com.redcode.im.androidapp.core.model.RoomMember
import java.time.Instant

@Entity(
    tableName = "room_members_cache",
    primaryKeys = ["roomId", "userId"],
    indices = [Index(value = ["roomId"]), Index(value = ["userId"]), Index(value = ["role"])],
)
data class RoomMemberEntity(
    val roomId: String,
    val userId: String,
    val username: String,
    val nickname: String?,
    val avatarUrl: String?,
    val role: String,
    val joinedAtMillis: Long?,
) {
    fun toDomain(): RoomMember =
        RoomMember(
            userId = userId,
            username = username,
            nickname = nickname,
            avatarUrl = avatarUrl,
            role = role,
            joinedAt = joinedAtMillis?.let(Instant::ofEpochMilli),
        )

    companion object {
        fun fromDomain(roomId: String, member: RoomMember): RoomMemberEntity =
            RoomMemberEntity(
                roomId = roomId,
                userId = member.userId,
                username = member.username,
                nickname = member.nickname,
                avatarUrl = member.avatarUrl,
                role = member.role,
                joinedAtMillis = member.joinedAt?.toEpochMilli(),
            )
    }
}
