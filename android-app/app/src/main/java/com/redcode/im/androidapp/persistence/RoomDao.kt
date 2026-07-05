package com.redcode.im.androidapp.persistence

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface RoomDao {
    @Query(
        """
        SELECT * FROM rooms_cache
        ORDER BY name COLLATE NOCASE ASC
        """,
    )
    fun observeRooms(): Flow<List<RoomInfoEntity>>

    @Query(
        """
        SELECT * FROM room_members_cache
        WHERE roomId = :roomId
        ORDER BY
          CASE role
            WHEN 'owner' THEN 0
            WHEN 'admin' THEN 1
            ELSE 2
          END ASC,
          username COLLATE NOCASE ASC
        """,
    )
    fun observeMembers(roomId: String): Flow<List<RoomMemberEntity>>

    @Query("SELECT * FROM group_settings_cache WHERE roomId = :roomId LIMIT 1")
    fun observeSettings(roomId: String): Flow<GroupSettingsEntity?>

    @Query("SELECT * FROM rooms_cache WHERE id = :roomId LIMIT 1")
    suspend fun findRoom(roomId: String): RoomInfoEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertRoom(room: RoomInfoEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertRooms(rooms: List<RoomInfoEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMembers(members: List<RoomMemberEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSettings(settings: GroupSettingsEntity)

    @Query("DELETE FROM rooms_cache")
    suspend fun clearRooms()

    @Query("DELETE FROM room_members_cache WHERE roomId = :roomId")
    suspend fun clearMembers(roomId: String)

    @Query("DELETE FROM room_members_cache WHERE roomId = :roomId AND userId = :userId")
    suspend fun removeMember(roomId: String, userId: String)

    @Query("DELETE FROM rooms_cache WHERE id = :roomId")
    suspend fun deleteRoomInfo(roomId: String)

    @Query("DELETE FROM group_settings_cache WHERE roomId = :roomId")
    suspend fun deleteSettings(roomId: String)

    @Query("DELETE FROM room_members_cache")
    suspend fun clearAllMembers()

    @Query("DELETE FROM group_settings_cache")
    suspend fun clearAllSettings()

    @Transaction
    suspend fun replaceRooms(rooms: List<RoomInfoEntity>) {
        clearRooms()
        upsertRooms(rooms)
    }

    @Transaction
    suspend fun replaceMembers(roomId: String, members: List<RoomMemberEntity>) {
        clearMembers(roomId)
        upsertMembers(members)
    }

    @Transaction
    suspend fun removeRoom(roomId: String) {
        clearMembers(roomId)
        deleteSettings(roomId)
        deleteRoomInfo(roomId)
    }

    @Transaction
    suspend fun clearAll() {
        clearAllMembers()
        clearAllSettings()
        clearRooms()
    }
}
