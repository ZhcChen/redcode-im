package com.redcode.im.androidapp.data.media

import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class CachedFileResource(
    val key: String,
    val localPath: String,
    val size: Long,
)

class FileResourceCache(
    private val rootDirectory: File,
) {
    suspend fun get(key: String, expectedSize: Long? = null): CachedFileResource? =
        withContext(Dispatchers.IO) {
            val normalizedKey = key.trim().takeIf { it.isNotBlank() } ?: return@withContext null
            val file = fileFor(normalizedKey)
            if (!file.isFile || !file.isValid(expectedSize)) {
                file.delete()
                return@withContext null
            }
            CachedFileResource(key = normalizedKey, localPath = file.absolutePath, size = file.length())
        }

    suspend fun put(key: String, bytes: ByteArray, expectedSize: Long? = bytes.size.toLong()): CachedFileResource =
        withContext(Dispatchers.IO) {
            val normalizedKey = key.trim()
            require(normalizedKey.isNotBlank()) { "cache key 不能为空" }
            if (expectedSize != null) {
                require(bytes.size.toLong() == expectedSize) { "缓存文件大小不匹配" }
            }
            rootDirectory.mkdirs()
            val target = fileFor(normalizedKey)
            val temp = File(target.parentFile, "${target.name}.tmp")
            temp.writeBytes(bytes)
            if (target.exists()) target.delete()
            check(temp.renameTo(target)) { "写入缓存文件失败" }
            CachedFileResource(key = normalizedKey, localPath = target.absolutePath, size = target.length())
        }

    suspend fun getOrPut(
        key: String,
        expectedSize: Long? = null,
        loader: suspend () -> ByteArray,
    ): CachedFileResource {
        get(key = key, expectedSize = expectedSize)?.let { return it }
        return put(key = key, bytes = loader(), expectedSize = expectedSize)
    }

    suspend fun remove(key: String) {
        withContext(Dispatchers.IO) {
            key.trim().takeIf { it.isNotBlank() }?.let { fileFor(it).delete() }
        }
    }

    suspend fun clear() {
        withContext(Dispatchers.IO) {
            if (rootDirectory.exists()) {
                rootDirectory.deleteRecursively()
            }
            rootDirectory.mkdirs()
        }
    }

    private fun fileFor(key: String): File =
        File(rootDirectory, "${sha256(key)}${extensionFor(key)}")

    private fun File.isValid(expectedSize: Long?): Boolean {
        if (!exists() || !isFile) return false
        if (expectedSize != null) return length() == expectedSize
        return length() > 0L
    }

    private fun extensionFor(key: String): String {
        val lastSegment = key.substringAfterLast('/')
        val extension =
            lastSegment
                .substringAfterLast('.', missingDelimiterValue = "")
                .lowercase()
                .filter { it in 'a'..'z' || it in '0'..'9' }
                .take(12)
        return if (extension.isBlank()) ".bin" else ".$extension"
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
