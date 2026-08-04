package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.emoji.EmojiAPIEndpoint
import com.redcode.im.androidapp.data.emoji.EmojiRemoteDataSource
import com.redcode.im.androidapp.data.emoji.RemoteEmojiRepository
import com.redcode.im.androidapp.data.media.FileResourceCache
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class EmojiRepositoryTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun emojiEndpoint_buildsDownloadUrlWithEncodedObjectKeyAndBoundedExpiry() {
        assertEquals(
            "http://10.0.2.2:8010/emoji-packs/download-url?object_key=emoji-items%2Fsmile+one.gif&expires_in_seconds=60",
            EmojiAPIEndpoint.downloadUrl("emoji-items/smile one.gif", expiresInSeconds = 1).url(RedCodeEnvironment.localEmulator()),
        )
    }

    @Test
    fun loadStickerPacks_returnsRemotePacksWithItems() =
        runTest {
            val remote =
                FakeEmojiRemoteDataSource(
                    packs =
                        listOf(
                            StickerPack(
                                id = "pack-1",
                                name = "常用",
                                items =
                                    listOf(
                                        StickerItem(id = "sticker-1", label = "OK", imageObjectKey = "emoji-items/ok.gif"),
                                    ),
                            ),
                        ),
                )
            val repository = repository(remote)

            val packs = repository.loadStickerPacks()

            assertEquals("pack-1", packs.single().id)
            assertEquals("sticker-1", packs.single().items.single().id)
            assertEquals(listOf("access-token"), remote.tokens)
        }

    @Test
    fun prepareStickerUpload_downloadsAndReusesFileCache() =
        runTest {
            val remote = FakeEmojiRemoteDataSource(bytes = "gif-bytes".encodeToByteArray())
            val repository = repository(remote)
            val sticker = StickerItem(id = "ok", label = "OK", imageObjectKey = "emoji-items/ok.gif")

            val first = repository.prepareStickerUpload(sticker)
            val second = repository.prepareStickerUpload(sticker)

            assertEquals("ok.gif", first?.fileName)
            assertEquals("image/gif", first?.mime)
            assertArrayEquals("gif-bytes".encodeToByteArray(), first?.bytes)
            assertArrayEquals(first?.bytes, second?.bytes)
            assertEquals(1, remote.downloadUrlRequests)
            assertEquals(1, remote.downloadRequests)
        }

    @Test
    fun prepareStickerUpload_ignoresImageUrlOnlySticker() =
        runTest {
            val remote = FakeEmojiRemoteDataSource(bytes = "gif-bytes".encodeToByteArray())
            val repository = repository(remote)
            val sticker = StickerItem(id = "ok", label = "OK", imageUrl = "https://asset.example/ok.gif")

            val upload = repository.prepareStickerUpload(sticker)

            assertEquals(null, upload)
            assertEquals(0, remote.downloadUrlRequests)
            assertEquals(0, remote.downloadRequests)
        }

    @Test
    fun clearLocalState_removesCachedEmojiFiles() =
        runTest {
            val remote = FakeEmojiRemoteDataSource(bytes = "gif-bytes".encodeToByteArray())
            val repository = repository(remote)
            val sticker = StickerItem(id = "ok", label = "OK", imageObjectKey = "emoji-items/ok.gif")
            repository.prepareStickerUpload(sticker)

            repository.clearLocalState()

            assertTrue(temporaryFolder.root.walkTopDown().filter { it.isFile }.none())
        }

    private fun repository(remote: FakeEmojiRemoteDataSource): RemoteEmojiRepository =
        RemoteEmojiRepository(
            remoteDataSource = remote,
            session =
                MutableStateFlow(
                    AuthSession(
                        user = AuthUser(id = "user-me", accountName = "me", displayName = "Me"),
                        tokens = TokenPair(accessToken = "access-token", refreshToken = "refresh-token"),
                    ),
                ),
            cache = FileResourceCache(temporaryFolder.newFolder("emoji")),
        )

    private class FakeEmojiRemoteDataSource(
        private val packs: List<StickerPack> = emptyList(),
        private val bytes: ByteArray = ByteArray(0),
    ) : EmojiRemoteDataSource {
        val tokens = mutableListOf<String>()
        var downloadUrlRequests = 0
        var downloadRequests = 0

        override suspend fun fetchMyPacks(token: String): List<StickerPack> {
            tokens += token
            return packs
        }

        override suspend fun fetchDownloadUrl(objectKey: String, token: String, expiresInSeconds: Int): String? {
            tokens += token
            downloadUrlRequests += 1
            return "https://example.test/$objectKey"
        }

        override suspend fun downloadBytes(url: String, maxBytes: Long): ByteArray {
            downloadRequests += 1
            assertEquals(EmojiRemoteDataSource.MAX_STICKER_DOWNLOAD_BYTES, maxBytes)
            return bytes
        }
    }
}
