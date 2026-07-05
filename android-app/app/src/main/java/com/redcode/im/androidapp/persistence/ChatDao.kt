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

    @Query("SELECT * FROM chat_summaries WHERE roomId = :roomId LIMIT 1")
    suspend fun findSummary(roomId: String): ChatSummaryEntity?

    @Query("SELECT EXISTS(SELECT 1 FROM chat_messages WHERE id = :messageId)")
    suspend fun hasMessage(messageId: String): Boolean

    @Query("SELECT * FROM chat_messages WHERE id = :messageId LIMIT 1")
    suspend fun findMessage(messageId: String): ChatMessageEntity?

    @Query("UPDATE chat_messages SET text = :text WHERE roomId = :roomId AND id = :messageId")
    suspend fun updateMessageText(roomId: String, messageId: String, text: String)

    @Query("UPDATE chat_messages SET text = :text, isDeleted = 1, isPinned = 0, pinnedAtMillis = NULL, pinnedBy = NULL WHERE roomId = :roomId AND id = :messageId")
    suspend fun updateMessageDeleted(roomId: String, messageId: String, text: String)

    @Query("UPDATE chat_messages SET status = :status WHERE id = :messageId")
    suspend fun updateMessageStatus(messageId: String, status: String)

    @Query("UPDATE chat_messages SET isPinned = :isPinned, pinnedAtMillis = :pinnedAtMillis, pinnedBy = :pinnedBy WHERE roomId = :roomId AND id = :messageId")
    suspend fun updateMessagePin(roomId: String, messageId: String, isPinned: Boolean, pinnedAtMillis: Long?, pinnedBy: String?)

    @Query("UPDATE chat_messages SET reactionsJson = :reactionsJson WHERE roomId = :roomId AND id = :messageId")
    suspend fun updateMessageReactions(roomId: String, messageId: String, reactionsJson: String)

    @Query("DELETE FROM chat_messages WHERE id = :messageId")
    suspend fun deleteMessage(messageId: String)

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

    @Query("DELETE FROM chat_messages WHERE roomId = :roomId")
    suspend fun clearMessages(roomId: String)

    @Query("DELETE FROM chat_summaries WHERE roomId = :roomId")
    suspend fun deleteSummary(roomId: String)

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

    @Transaction
    suspend fun deleteRoom(roomId: String) {
        clearMessages(roomId)
        deleteSummary(roomId)
    }
}
