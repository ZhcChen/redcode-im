package com.redcode.im.androidapp.persistence

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        ChatSummaryEntity::class,
        ChatMessageEntity::class,
        ContactEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class RedCodeDatabase : RoomDatabase() {
    abstract fun chatDao(): ChatDao

    abstract fun contactDao(): ContactDao
}
