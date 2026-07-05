package com.redcode.im.androidapp.persistence

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface ChatDao {
    @Query(
        """
        SELECT * FROM chat_summaries
        ORDER BY isPinned DESC, updatedAtMillis DESC, title COLLATE NOCASE ASC
        """,
    )
    fun observeSummaries(): Flow<List<ChatSummaryEntity>>

    @Query(
        """
        SELECT * FROM chat_messages
        WHERE roomId = :roomId
        ORDER BY createdAtMillis ASC
        """,
    )
    fun observeMessages(roomId: String): Flow<List<ChatMessageEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSummary(summary: ChatSummaryEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSummaries(summaries: List<ChatSummaryEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMessage(message: ChatMessageEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMessages(messages: List<ChatMessageEntity>)

    @Query("UPDATE chat_summaries SET unreadCount = 0 WHERE roomId = :roomId")
    suspend fun markRead(roomId: String)

    @Query(
        """
        DELETE FROM chat_messages
        WHERE roomId = :roomId
          AND id NOT IN (
            SELECT id FROM chat_messages
            WHERE roomId = :roomId
            ORDER BY createdAtMillis DESC
            LIMIT :keep
          )
        """,
    )
    suspend fun pruneMessages(roomId: String, keep: Int)

    @Query("DELETE FROM chat_messages")
    suspend fun clearMessages()

    @Query("DELETE FROM chat_summaries")
    suspend fun clearSummaries()

    @Transaction
    suspend fun replaceMessages(roomId: String, messages: List<ChatMessageEntity>, keep: Int) {
        upsertMessages(messages)
        pruneMessages(roomId, keep)
    }

    @Transaction
    suspend fun replaceSummaries(summaries: List<ChatSummaryEntity>) {
        clearSummaries()
        upsertSummaries(summaries)
    }

    @Transaction
    suspend fun clearAll() {
        clearMessages()
        clearSummaries()
    }
}
