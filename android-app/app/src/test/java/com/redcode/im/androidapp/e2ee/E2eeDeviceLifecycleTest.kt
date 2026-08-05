package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.network.NetworkFailure
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class E2eeDeviceLifecycleTest {
    private lateinit var storage: E2eeSecureStateStore
    private lateinit var mlsApi: FakeMlsApi
    private lateinit var lifecycle: E2eeDeviceLifecycle
    private var now = 0L

    @Before
    fun setUp() {
        storage =
            E2eeSecureStateStore(
                cipher = InMemoryE2eeStateCipher(),
                blobs = InMemoryE2eeStateBlobStore(),
            )
        mlsApi = FakeMlsApi()
        now = 1_000_000L
        lifecycle =
            E2eeDeviceLifecycle(
                storage = storage,
                mlsApi = mlsApi,
                core = E2eeCommandClient(),
                newDeviceId = { "device-android-test" },
                nowMillis = { now },
            )
    }

    @Test
    fun ensureReadyRegistersDeviceAndPublishesFirstKeyPackage() = runTest {
        val profile = lifecycle.ensureReady("account-a", "Android Test", "token")

        assertEquals("device-android-test", profile.deviceId)
        assertTrue(profile.registered)
        assertTrue(profile.keyPackagePublished)
        assertEquals("active", profile.deviceStatus)
        assertEquals(1, mlsApi.registerCount.get())
        assertEquals(1, mlsApi.publishedTotal.get())
        assertEquals(1, mlsApi.inventory)
        assertTrue(storage.read("account-a")!!.isNotEmpty())
    }

    @Test
    fun topUpRefillsFromLowWatermarkInBatches() = runTest {
        lifecycle.ensureReady("account-a", "Android Test", "token")
        mlsApi.inventory = 0

        val inserted = lifecycle.topUpKeyPackages("account-a", "token")

        assertEquals(20, inserted)
        assertEquals(21, mlsApi.publishedTotal.get())
        assertEquals(20, mlsApi.inventory)
    }

    @Test
    fun topUpAfterClaimsRefillsRemainingCapacity() = runTest {
        lifecycle.ensureReady("account-a", "Android Test", "token")
        mlsApi.inventory = 5

        val inserted = lifecycle.topUpKeyPackages("account-a", "token")

        assertEquals(20, inserted)
        assertEquals(21, mlsApi.publishedTotal.get())
        assertEquals(25, mlsApi.inventory)
    }

    @Test
    fun topUpSkippedWhenInventoryAboveLowWatermark() = runTest {
        lifecycle.ensureReady("account-a", "Android Test", "token")
        mlsApi.inventory = 12

        val inserted = lifecycle.topUpKeyPackages("account-a", "token")

        assertEquals(0, inserted)
        assertEquals(1, mlsApi.publishedTotal.get())
    }

    @Test
    fun concurrentTopUpsShareSingleFlight() = runTest {
        lifecycle.ensureReady("account-a", "Android Test", "token")
        mlsApi.inventory = 0
        mlsApi.publishDelayMillis = 50L

        val results =
            (1..5).map {
                async { lifecycle.topUpKeyPackages("account-a", "token") }
            }.awaitAll()

        assertEquals(listOf(20), results.distinct())
        assertEquals(2, mlsApi.publishCalls.get())
        assertEquals(21, mlsApi.publishedTotal.get())
    }

    @Test
    fun revokedDevicePublishFailsThenBacksOffAndRecovers() = runTest {
        lifecycle.ensureReady("account-a", "Android Test", "token")
        mlsApi.inventory = 0
        mlsApi.publishShouldFail = true

        val failure = runCatching { lifecycle.topUpKeyPackages("account-a", "token") }
            .exceptionOrNull()
        assertTrue(failure is NetworkFailure)

        // 退避窗口内不再重试。
        assertEquals(0, lifecycle.topUpKeyPackages("account-a", "token"))

        // 窗口过后恢复补充。
        now += 61_000L
        mlsApi.publishShouldFail = false
        assertEquals(20, lifecycle.topUpKeyPackages("account-a", "token"))
    }

    @Test
    fun pendingApprovalDeviceCannotTopUp() = runTest {
        mlsApi.registerStatus = "pending_approval"
        val profile = lifecycle.ensureReady("account-a", "Android Test", "token")

        assertEquals("pending_approval", profile.deviceStatus)
        assertFalse(profile.keyPackagePublished)
        val failure = runCatching { lifecycle.topUpKeyPackages("account-a", "token") }
            .exceptionOrNull()
        assertTrue(failure is E2eeDeviceNotReadyException)
    }

    @Test
    fun missingStateWithRegisteredProfileRejectsReinitialization() = runTest {
        storage.writeProfile(
            "account-a",
            E2eeDeviceProfile(
                deviceId = "device-x",
                deviceLabel = "X",
                registered = true,
            ),
        )

        val failure = runCatching { lifecycle.ensureReady("account-a", "Android Test", "token") }
            .exceptionOrNull()
        assertTrue(failure is E2eeDeviceNotReadyException)
    }

    private class FakeMlsApi : E2eeMlsApi {
        val registerCount = AtomicInteger(0)
        val publishCalls = AtomicInteger(0)
        val publishedTotal = AtomicInteger(0)
        var inventory = 0
        var registerStatus = "active"
        var publishShouldFail = false
        var publishDelayMillis = 0L

        override suspend fun fetchRootIdentity(userId: String, token: String): ByteArray =
            throw NetworkFailure(statusCode = 404, message = "not found")

        override suspend fun registerDevice(
            deviceId: String,
            deviceLabel: String,
            material: E2eeRegistrationMaterial,
            token: String,
        ): String {
            registerCount.incrementAndGet()
            return registerStatus
        }

        override suspend fun publishKeyPackages(
            deviceId: String,
            keyPackages: List<ByteArray>,
            token: String,
        ): Int {
            publishCalls.incrementAndGet()
            if (publishDelayMillis > 0) kotlinx.coroutines.delay(publishDelayMillis)
            if (publishShouldFail) {
                throw NetworkFailure(statusCode = 403, message = "device revoked")
            }
            publishedTotal.addAndGet(keyPackages.size)
            inventory += keyPackages.size
            return keyPackages.size
        }

        override suspend fun fetchKeyPackageInventory(deviceId: String, token: String): E2eeKeyPackageInventory =
            E2eeKeyPackageInventory(available = inventory, maxAvailable = 100)

        override suspend fun listDevices(token: String): List<E2eeDeviceInfo> =
            listOf(E2eeDeviceInfo(id = "device-android-test", status = "active"))
    }
}
