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
        RoomInfoEntity::class,
        RoomMemberEntity::class,
        GroupSettingsEntity::class,
        E2eeStateEntity::class,
        E2eeBlobEntity::class,
    ],
    version = 8,
    exportSchema = false,
)
abstract class RedCodeDatabase : RoomDatabase() {
    abstract fun chatDao(): ChatDao

    abstract fun contactDao(): ContactDao

    abstract fun roomDao(): RoomDao

    abstract fun e2eeStateDao(): E2eeStateDao

    abstract fun e2eeBlobDao(): E2eeBlobDao
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

val MIGRATION_2_3 =
    object : Migration(2, 3) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedMessageId TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedRoomId TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedSenderId TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedSenderName TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedText TEXT")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedCreatedAtMillis INTEGER")
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN quotedIsDeleted INTEGER NOT NULL DEFAULT 0")
        }
    }

val MIGRATION_3_4 =
    object : Migration(3, 4) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS rooms_cache (
                    id TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL,
                    roomType TEXT NOT NULL,
                    description TEXT,
                    avatarUrl TEXT,
                    ownerId TEXT,
                    createdAtMillis INTEGER,
                    updatedAtMillis INTEGER
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX IF NOT EXISTS index_rooms_cache_name ON rooms_cache(name)")
            db.execSQL("CREATE INDEX IF NOT EXISTS index_rooms_cache_roomType ON rooms_cache(roomType)")
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS room_members_cache (
                    roomId TEXT NOT NULL,
                    userId TEXT NOT NULL,
                    username TEXT NOT NULL,
                    nickname TEXT,
                    avatarUrl TEXT,
                    role TEXT NOT NULL,
                    joinedAtMillis INTEGER,
                    PRIMARY KEY(roomId, userId)
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX IF NOT EXISTS index_room_members_cache_roomId ON room_members_cache(roomId)")
            db.execSQL("CREATE INDEX IF NOT EXISTS index_room_members_cache_userId ON room_members_cache(userId)")
            db.execSQL("CREATE INDEX IF NOT EXISTS index_room_members_cache_role ON room_members_cache(role)")
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS group_settings_cache (
                    roomId TEXT NOT NULL PRIMARY KEY,
                    joinApprovalRequired INTEGER NOT NULL,
                    memberCanInvite INTEGER NOT NULL,
                    memberCanAddFriends INTEGER NOT NULL,
                    requireAdminToAddFriends INTEGER NOT NULL,
                    maxMembers INTEGER NOT NULL,
                    globalMuteEnabled INTEGER NOT NULL,
                    globalMuteUntilMillis INTEGER,
                    globalMuteReason TEXT,
                    globalMuteSetBy TEXT,
                    myIsMuted INTEGER NOT NULL,
                    myMuteReason TEXT,
                    myMutedAtMillis INTEGER,
                    myMuteUntilMillis INTEGER
                )
                """.trimIndent(),
            )
        }
    }

val MIGRATION_4_5 =
    object : Migration(4, 5) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE chat_messages ADD COLUMN partsJson TEXT NOT NULL DEFAULT '[]'")
        }
    }

val MIGRATION_5_6 =
    object : Migration(5, 6) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE chat_summaries ADD COLUMN avatarUrl TEXT")
            db.execSQL("ALTER TABLE chat_summaries ADD COLUMN avatarObjectKey TEXT")
            db.execSQL("ALTER TABLE chat_summaries ADD COLUMN friendUserId TEXT")
            db.execSQL("ALTER TABLE contacts ADD COLUMN avatarObjectKey TEXT")
            db.execSQL("ALTER TABLE rooms_cache ADD COLUMN avatarObjectKey TEXT")
            db.execSQL("ALTER TABLE room_members_cache ADD COLUMN avatarObjectKey TEXT")
        }
    }

val MIGRATION_6_7 =
    object : Migration(6, 7) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS e2ee_states (
                    accountId TEXT NOT NULL PRIMARY KEY,
                    version INTEGER NOT NULL,
                    nonce BLOB NOT NULL,
                    ciphertext BLOB NOT NULL
                )
                """.trimIndent(),
            )
        }
    }

val MIGRATION_7_8 =
    object : Migration(7, 8) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS e2ee_blobs (
                    accountId TEXT NOT NULL,
                    blobKey TEXT NOT NULL,
                    version INTEGER NOT NULL,
                    nonce BLOB NOT NULL,
                    ciphertext BLOB NOT NULL,
                    PRIMARY KEY(accountId, blobKey)
                )
                """.trimIndent(),
            )
        }
    }
