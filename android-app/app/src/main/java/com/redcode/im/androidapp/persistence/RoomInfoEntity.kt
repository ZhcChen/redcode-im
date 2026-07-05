package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.RoomInfo
import java.time.Instant

@Entity(
    tableName = "rooms_cache",
    indices = [Index(value = ["name"]), Index(value = ["roomType"])],
)
data class RoomInfoEntity(
    @PrimaryKey val id: String,
    val name: String,
    val roomType: String,
    val description: String?,
    val avatarUrl: String?,
    val ownerId: String?,
    val createdAtMillis: Long?,
    val updatedAtMillis: Long?,
) {
    fun toDomain(): RoomInfo =
        RoomInfo(
            id = id,
            name = name,
            roomType = roomType,
            description = description,
            avatarUrl = avatarUrl,
            ownerId = ownerId,
            createdAt = createdAtMillis?.let(Instant::ofEpochMilli),
            updatedAt = updatedAtMillis?.let(Instant::ofEpochMilli),
        )

    companion object {
        fun fromDomain(room: RoomInfo): RoomInfoEntity =
            RoomInfoEntity(
                id = room.id,
                name = room.name,
                roomType = room.roomType,
                description = room.description,
                avatarUrl = room.avatarUrl,
                ownerId = room.ownerId,
                createdAtMillis = room.createdAt?.toEpochMilli(),
                updatedAtMillis = room.updatedAt?.toEpochMilli(),
            )
    }
}
