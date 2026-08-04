package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.data.media.FileResourceCache
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class FileResourceCacheTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun putAndGet_returnsCachedFileForSameKey() =
        runTest {
            val cache = FileResourceCache(temporaryFolder.newFolder("attachments"))
            val bytes = "file-bytes".encodeToByteArray()

            val saved = cache.put(key = "messages/room-1/files/a.txt", bytes = bytes)
            val cached = cache.get(key = "messages/room-1/files/a.txt", expectedSize = bytes.size.toLong())

            assertEquals(saved.localPath, cached?.localPath)
            assertEquals(bytes.toList(), File(saved.localPath).readBytes().toList())
        }

    @Test
    fun get_removesCorruptedSizeMismatch() =
        runTest {
            val cache = FileResourceCache(temporaryFolder.newFolder("attachments"))
            val saved = cache.put(key = "messages/room-1/files/a.txt", bytes = "ok".encodeToByteArray())

            val cached = cache.get(key = "messages/room-1/files/a.txt", expectedSize = 99)

            assertNull(cached)
            assertEquals(false, File(saved.localPath).exists())
        }

    @Test
    fun getOrPut_doesNotCreateFileWhenLoaderFails() =
        runTest {
            val root = temporaryFolder.newFolder("attachments")
            val cache = FileResourceCache(root)

            val error =
                runCatching {
                    cache.getOrPut(key = "messages/room-1/files/a.txt") {
                        error("download failed")
                    }
                }.exceptionOrNull()

            assertEquals("download failed", error?.message)
            assertTrue(root.listFiles().orEmpty().isEmpty())
        }

    @Test
    fun clear_removesAllCachedFiles() =
        runTest {
            val root = temporaryFolder.newFolder("attachments")
            val cache = FileResourceCache(root)
            cache.put(key = "messages/room-1/files/a.txt", bytes = "a".encodeToByteArray())
            cache.put(key = "messages/room-1/files/b.txt", bytes = "b".encodeToByteArray())

            cache.clear()

            assertTrue(root.listFiles().orEmpty().isEmpty())
        }
}
