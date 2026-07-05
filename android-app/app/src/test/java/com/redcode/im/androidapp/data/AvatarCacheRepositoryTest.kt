package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.media.AvatarAPIEndpoint
import com.redcode.im.androidapp.data.media.AvatarCacheRepository
import com.redcode.im.androidapp.data.media.AvatarRemoteDataSource
import com.redcode.im.androidapp.data.media.FileResourceCache
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AvatarCacheRepositoryTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun avatarEndpoints_buildExpectedDownloadUrlPaths() {
        val environment = RedCodeEnvironment.localEmulator()

        assertEquals(
            "http://10.0.2.2:8010/users/me/avatar/url?expires_in_seconds=3600",
            AvatarAPIEndpoint.currentUserAvatarDownloadUrl().url(environment),
        )
        assertEquals(
            "http://10.0.2.2:8010/users/user-1/avatar/url?expires_in_seconds=60",
            AvatarAPIEndpoint.userAvatarDownloadUrl("user-1", expiresInSeconds = 1).url(environment),
        )
        assertEquals(
            "http://10.0.2.2:8010/rooms/room-1/avatar/url?expires_in_seconds=86400",
            AvatarAPIEndpoint.roomAvatarDownloadUrl("room-1", expiresInSeconds = 999_999).url(environment),
        )
    }

    @Test
    fun loadUserAvatar_usesLocalCacheBeforeRequestingDownloadUrlAgain() =
        runTest {
            val remote = FakeAvatarRemoteDataSource(bytesByUrl = mutableMapOf("https://asset.example/u1.png" to "avatar".encodeToByteArray()))
            val repository = repository(remote)

            val first = repository.loadUserAvatar(userId = "user-1", objectKey = "avatars/user-1/a.png", token = "token")
            val second = repository.loadUserAvatar(userId = "user-1", objectKey = "avatars/user-1/a.png", token = "token")

            assertEquals(first?.localPath, second?.localPath)
            assertEquals(1, remote.userUrlRequests)
            assertEquals(1, remote.downloadRequests)
            assertEquals("avatar", File(first!!.localPath).readText())
        }

    @Test
    fun loadCurrentUserAvatar_usesMeEndpointFetcher() =
        runTest {
            val remote = FakeAvatarRemoteDataSource(bytesByUrl = mutableMapOf("https://asset.example/me.png" to "me".encodeToByteArray()))
            val repository = repository(remote)

            val avatar = repository.loadCurrentUserAvatar(userId = "user-me", objectKey = "avatars/user-me/a.png", token = "token")

            assertEquals("me", File(avatar!!.localPath).readText())
            assertEquals(1, remote.currentUserUrlRequests)
            assertEquals(0, remote.userUrlRequests)
        }

    @Test
    fun loadRoomAvatar_objectKeyChangeCreatesNewCachedFile() =
        runTest {
            val remote =
                FakeAvatarRemoteDataSource(
                    bytesByUrl =
                        mutableMapOf(
                            "https://asset.example/r1-a.png" to "first".encodeToByteArray(),
                            "https://asset.example/r1-b.png" to "second".encodeToByteArray(),
                        ),
                )
            val repository = repository(remote)

            val first = repository.loadRoomAvatar(roomId = "room-1", objectKey = "room_avatars/room-1/a.png", token = "token")
            val second = repository.loadRoomAvatar(roomId = "room-1", objectKey = "room_avatars/room-1/b.png", token = "token")

            assertTrue(first?.localPath != second?.localPath)
            assertEquals("first", File(first!!.localPath).readText())
            assertEquals("second", File(second!!.localPath).readText())
            assertEquals(2, remote.roomUrlRequests)
        }

    @Test
    fun loadAvatar_downloadFailureReturnsNullAndDoesNotPolluteCache() =
        runTest {
            val remote = FakeAvatarRemoteDataSource(bytesByUrl = mutableMapOf())
            val repository = repository(remote)

            val failed = repository.loadUserAvatar(userId = "user-1", objectKey = "avatars/user-1/a.png", token = "token")
            remote.bytesByUrl["https://asset.example/u1.png"] = "ok".encodeToByteArray()
            val recovered = repository.loadUserAvatar(userId = "user-1", objectKey = "avatars/user-1/a.png", token = "token")

            assertNull(failed)
            assertEquals("ok", File(recovered!!.localPath).readText())
            assertEquals(2, remote.userUrlRequests)
            assertEquals(2, remote.downloadRequests)
        }

    @Test
    fun clearRemovesCachedAvatars() =
        runTest {
            val remote = FakeAvatarRemoteDataSource(bytesByUrl = mutableMapOf("https://asset.example/u1.png" to "avatar".encodeToByteArray()))
            val repository = repository(remote)
            val first = repository.loadUserAvatar(userId = "user-1", objectKey = "avatars/user-1/a.png", token = "token")

            repository.clear()

            assertTrue(!File(first!!.localPath).exists())
        }

    private fun repository(remote: FakeAvatarRemoteDataSource): AvatarCacheRepository =
        AvatarCacheRepository(
            remoteDataSource = remote,
            cache = FileResourceCache(temporaryFolder.newFolder("avatars")),
        )

    private class FakeAvatarRemoteDataSource(
        val bytesByUrl: MutableMap<String, ByteArray>,
    ) : AvatarRemoteDataSource {
        var currentUserUrlRequests = 0
        var userUrlRequests = 0
        var roomUrlRequests = 0
        var downloadRequests = 0

        override suspend fun fetchCurrentUserAvatarDownloadUrl(token: String, expiresInSeconds: Int): String? {
            currentUserUrlRequests += 1
            return "https://asset.example/me.png"
        }

        override suspend fun fetchUserAvatarDownloadUrl(userId: String, token: String, expiresInSeconds: Int): String? {
            userUrlRequests += 1
            return "https://asset.example/u1.png"
        }

        override suspend fun fetchRoomAvatarDownloadUrl(roomId: String, token: String, expiresInSeconds: Int): String? {
            roomUrlRequests += 1
            return if (roomUrlRequests == 1) "https://asset.example/r1-a.png" else "https://asset.example/r1-b.png"
        }

        override suspend fun downloadBytes(url: String): ByteArray {
            downloadRequests += 1
            return bytesByUrl[url] ?: error("missing bytes")
        }
    }
}
