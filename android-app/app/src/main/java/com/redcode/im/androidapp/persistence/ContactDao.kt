package com.redcode.im.androidapp.persistence

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ContactDao {
    @Query("SELECT * FROM contacts ORDER BY displayName COLLATE NOCASE ASC, accountName COLLATE NOCASE ASC")
    fun observeContacts(): Flow<List<ContactEntity>>

    @Query(
        """
        SELECT * FROM contacts
        WHERE accountName LIKE '%' || :query || '%'
           OR displayName LIKE '%' || :query || '%'
        ORDER BY displayName COLLATE NOCASE ASC, accountName COLLATE NOCASE ASC
        """,
    )
    suspend fun search(query: String): List<ContactEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(contact: ContactEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(contacts: List<ContactEntity>)

    @Query("DELETE FROM contacts WHERE userId = :userId")
    suspend fun remove(userId: String)

    @Query("DELETE FROM contacts")
    suspend fun clear()
}
