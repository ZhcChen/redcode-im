package com.redcode.im.androidapp.persistence

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

/** E2EE 附加密文记录（设备档案等），与 RCST 状态分表存储。 */
@Entity(
    tableName = "e2ee_blobs",
    primaryKeys = ["accountId", "blobKey"],
)
data class E2eeBlobEntity(
    val accountId: String,
    val blobKey: String,
    val version: Int,
    val nonce: ByteArray,
    val ciphertext: ByteArray,
)

@Dao
interface E2eeBlobDao {
    @Query("SELECT * FROM e2ee_blobs WHERE accountId = :accountId AND blobKey = :blobKey")
    fun find(accountId: String, blobKey: String): E2eeBlobEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(entity: E2eeBlobEntity)

    @Query("DELETE FROM e2ee_blobs WHERE accountId = :accountId AND blobKey = :blobKey")
    fun delete(accountId: String, blobKey: String)

    @Query("DELETE FROM e2ee_blobs WHERE accountId = :accountId")
    fun deleteAll(accountId: String)
}
