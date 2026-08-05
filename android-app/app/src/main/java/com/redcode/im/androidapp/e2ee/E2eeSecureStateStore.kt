package com.redcode.im.androidapp.e2ee

/**
 * E2EE 协议状态的 AES-GCM 密文封装，版本/布局与 H5 secure-state-storage 对齐：
 * version=1、12 字节 nonce、ciphertext（含 128 位 GCM tag），AAD 绑定账号。
 */
data class E2eeEncryptedStateBlob(
    val version: Int,
    val nonce: ByteArray,
    val ciphertext: ByteArray,
)

/** 密钥缺失、密文篡改或版本不匹配等 fail closed 场景的统一异常。 */
class E2eeStateCorruptedException(
    message: String = "E2EE 协议状态已损坏或无法解密",
) : Exception(message)

/** 平台安全能力缺失（Keystore/安全随机数不可用）时抛出。 */
class E2eeStorageUnavailableException(message: String) : Exception(message)

/** 按账号提供包装密钥的加解密原语；真实实现走 Android Keystore。 */
interface E2eeStateCipher {
    fun encrypt(accountId: String, plaintext: ByteArray): E2eeEncryptedStateBlob

    fun decrypt(accountId: String, blob: E2eeEncryptedStateBlob): ByteArray

    fun deleteKey(accountId: String)
}

/** 密文 blob 的持久化层；真实实现走 Room。 */
interface E2eeStateBlobStore {
    fun save(accountId: String, blob: E2eeEncryptedStateBlob)

    fun load(accountId: String): E2eeEncryptedStateBlob?

    fun delete(accountId: String)
}

/**
 * E2EE 协议状态的安全存储：先由共享核心校验状态，再用账号级包装密钥
 * AES-GCM 加密落盘；读取时任何密钥缺失/篡改/版本不匹配都 fail closed。
 */
class E2eeSecureStateStore(
    private val cipher: E2eeStateCipher,
    private val blobs: E2eeStateBlobStore,
    private val validateProtocolState: (ByteArray) -> Boolean =
        E2eeCommandClient()::validateProtocolState,
) {
    fun write(accountId: String, state: ByteArray) {
        requireAccountId(accountId)
        if (!validateProtocolState(state)) {
            throw E2eeStateCorruptedException("拒绝保存无效的 E2EE 协议状态")
        }
        blobs.save(accountId, cipher.encrypt(accountId, state))
    }

    fun read(accountId: String): ByteArray? {
        requireAccountId(accountId)
        val blob = blobs.load(accountId) ?: return null
        val state =
            try {
                cipher.decrypt(accountId, blob)
            } catch (e: E2eeStateCorruptedException) {
                throw e
            } catch (e: Exception) {
                throw E2eeStateCorruptedException()
            }
        if (!validateProtocolState(state)) {
            throw E2eeStateCorruptedException()
        }
        return state
    }

    /** 注销/切换账号时同时清除包装密钥与密文，避免残留可解密材料。 */
    fun delete(accountId: String) {
        requireAccountId(accountId)
        cipher.deleteKey(accountId)
        blobs.delete(accountId)
    }

    private fun requireAccountId(accountId: String) {
        if (accountId.isBlank()) {
            throw E2eeStateCorruptedException("E2EE 账号标识不能为空")
        }
    }
}

/** 与 H5 secure-state-storage 完全一致的 AAD 构造。 */
internal fun e2eeStateAssociatedData(accountId: String): ByteArray =
    "redcode-im/e2ee-state/v1\u0000${accountId.trim()}".toByteArray(Charsets.UTF_8)
