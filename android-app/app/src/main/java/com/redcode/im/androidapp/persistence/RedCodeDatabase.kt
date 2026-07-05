package com.redcode.im.androidapp.persistence

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        ChatSummaryEntity::class,
        ChatMessageEntity::class,
        ContactEntity::class,
    ],
    version = 2,
    exportSchema = false,
)
abstract class RedCodeDatabase : RoomDatabase() {
    abstract fun chatDao(): ChatDao

    abstract fun contactDao(): ContactDao
}

val MIGRATION_1_2 =
    object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN isPinned INTEGER NOT NULL DEFAULT 0")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN pinnedAtMillis INTEGER")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN pinnedBy TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN reactionsJson TEXT NOT NULL DEFAULT '[]'")
        }
    }
