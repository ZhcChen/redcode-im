package com.redcode.im.androidapp.live

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.redCodeDefaultStickerPacks
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.emoji.HttpEmojiRemoteDataSource
import com.redcode.im.androidapp.data.emoji.RemoteEmojiRepository
import com.redcode.im.androidapp.data.media.FileResourceCache
import com.redcode.im.androidapp.network.APIClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AndroidEmojiLiveSmokeTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun androidClientCanLoadEmojiPacksWithDefaultFallback() =
        runTest {
            assumeTrue(
                "Set RED_CODE_ANDROID_LIVE_SMOKE=1 when the local Compose API is running",
                liveSmokeEnabled(),
            )

            val apiClient = APIClient(liveEnvironment())
            val authDataSource = HttpAuthRemoteDataSource(apiClient)
            val session = registerAndLogin(authDataSource, "andem${randomSuffix()}")
            val repository =
                RemoteEmojiRepository(
                    remoteDataSource = HttpEmojiRemoteDataSource(apiClient),
                    session = MutableStateFlow(session),
                    cache = FileResourceCache(temporaryFolder.newFolder("emoji")),
                )

            val packs = repository.loadStickerPacks()

            assertTrue(packs.isNotEmpty())
            assertTrue(packs.any { it.items.isNotEmpty() })
            if (packs == redCodeDefaultStickerPacks) {
                assertTrue("空账号应稳定降级到内置默认贴纸", packs.single().items.isNotEmpty())
            } else {
                val sticker = packs.flatMap { it.items }.first { !it.imageObjectKey.isNullOrBlank() || !it.imageUrl.isNullOrBlank() }
                val first = repository.prepareStickerUpload(sticker)
                val second = repository.prepareStickerUpload(sticker)
                assertTrue(first?.bytes?.isNotEmpty() == true)
                assertEquals(first?.bytes?.size, second?.bytes?.size)
            }
        }

    private suspend fun registerAndLogin(authDataSource: HttpAuthRemoteDataSource, username: String): AuthSession {
        val password = "secret123"
        authDataSource.register(username = username, password = password, nickname = username)
        return authDataSource.login(username = username, password = password).toDomain()
    }

    private fun liveSmokeEnabled(): Boolean =
        System.getenv("RED_CODE_ANDROID_LIVE_SMOKE") == "1" ||
            System.getenv("RED_CODE_ANDROID_LIVE_EMOJI_SMOKE") == "1"

    private fun liveEnvironment(): RedCodeEnvironment =
        RedCodeEnvironment(
            apiBaseUrl = System.getenv("ANDROID_APP_LIVE_API_BASE_URL") ?: "http://127.0.0.1:8010",
            wsUrl = System.getenv("ANDROID_APP_LIVE_WS_URL") ?: "ws://127.0.0.1:8010/ws",
        )

    private fun randomSuffix(): String =
        System.nanoTime().toString(16).takeLast(8)
}
