package com.redcode.im.androidapp.persistence

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query

/** E2EE 协议状态密文 blob；明文永不落盘。 */
@Entity(tableName = "e2ee_states")
data class E2eeStateEntity(
    @PrimaryKey val accountId: String,
    val version: Int,
    val nonce: ByteArray,
    val ciphertext: ByteArray,
)

@Dao
interface E2eeStateDao {
    @Query("SELECT * FROM e2ee_states WHERE accountId = :accountId")
    fun find(accountId: String): E2eeStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(entity: E2eeStateEntity)

    @Query("DELETE FROM e2ee_states WHERE accountId = :accountId")
    fun delete(accountId: String)
}
