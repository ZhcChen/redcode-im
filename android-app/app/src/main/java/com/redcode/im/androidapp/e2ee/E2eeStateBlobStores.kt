package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.persistence.E2eeStateDao
import com.redcode.im.androidapp.persistence.E2eeBlobDao
import com.redcode.im.androidapp.persistence.E2eeStateEntity
import com.redcode.im.androidapp.persistence.E2eeBlobEntity

/** Room 实现的密文 blob 存储（表：e2ee_states）。 */
class RoomE2eeStateBlobStore(
    private val dao: E2eeStateDao,
    private val blobDao: E2eeBlobDao,
) : E2eeStateBlobStore {
    override fun save(accountId: String, blob: E2eeEncryptedStateBlob) {
        dao.upsert(
            E2eeStateEntity(
                accountId = accountId,
                version = blob.version,
                nonce = blob.nonce,
                ciphertext = blob.ciphertext,
            ),
        )
    }

    override fun load(accountId: String): E2eeEncryptedStateBlob? =
        dao.find(accountId)?.let {
            E2eeEncryptedStateBlob(
                version = it.version,
                nonce = it.nonce,
                ciphertext = it.ciphertext,
            )
        }

    override fun delete(accountId: String) {
        dao.delete(accountId)
    }

    override fun saveBlob(accountId: String, key: String, blob: E2eeEncryptedStateBlob) {
        blobDao.upsert(
            E2eeBlobEntity(
                accountId = accountId,
                blobKey = key,
                version = blob.version,
                nonce = blob.nonce,
                ciphertext = blob.ciphertext,
            ),
        )
    }

    override fun loadBlob(accountId: String, key: String): E2eeEncryptedStateBlob? =
        blobDao.find(accountId, key)?.let {
            E2eeEncryptedStateBlob(
                version = it.version,
                nonce = it.nonce,
                ciphertext = it.ciphertext,
            )
        }

    override fun deleteBlob(accountId: String, key: String) {
        blobDao.delete(accountId, key)
    }

    override fun deleteAllBlobs(accountId: String) {
        blobDao.deleteAll(accountId)
    }
}

/** JVM 测试用内存 blob 存储。 */
class InMemoryE2eeStateBlobStore : E2eeStateBlobStore {
    private val records = mutableMapOf<String, E2eeEncryptedStateBlob>()
    private val keyedRecords = mutableMapOf<String, MutableMap<String, E2eeEncryptedStateBlob>>()

    override fun save(accountId: String, blob: E2eeEncryptedStateBlob) {
        records[accountId] = blob
    }

    override fun load(accountId: String): E2eeEncryptedStateBlob? = records[accountId]

    override fun delete(accountId: String) {
        records.remove(accountId)
    }

    override fun saveBlob(accountId: String, key: String, blob: E2eeEncryptedStateBlob) {
        keyedRecords.getOrPut(accountId) { mutableMapOf() }[key] = blob
    }

    override fun loadBlob(accountId: String, key: String): E2eeEncryptedStateBlob? =
        keyedRecords[accountId]?.get(key)

    override fun deleteBlob(accountId: String, key: String) {
        keyedRecords[accountId]?.remove(key)
    }

    override fun deleteAllBlobs(accountId: String) {
        keyedRecords.remove(accountId)
    }
}
