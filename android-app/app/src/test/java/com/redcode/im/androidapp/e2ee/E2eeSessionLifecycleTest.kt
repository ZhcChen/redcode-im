package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.MessageRuntimeSettings
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.data.settings.SettingsRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class E2eeSessionLifecycleTest {
    @Test
    fun plaintextRuntime_doesNotInitializeDevice() = runTest {
        val fixture = Fixture(MessageRuntimeSettings())

        fixture.lifecycle.onAuthenticated("account-a", "token")

        assertEquals(E2eeSessionStatus.Plaintext, fixture.lifecycle.status.value)
        assertEquals(0, fixture.devices.ensureCalls)
    }

    @Test
    fun e2eeRuntime_initializesAndTopsUpOncePerEvent() = runTest {
        val fixture = Fixture(MessageRuntimeSettings(contentAuditMode = "e2ee"))

        fixture.lifecycle.onAuthenticated("account-a", "token")
        fixture.lifecycle.onForeground()

        assertTrue(fixture.lifecycle.status.value is E2eeSessionStatus.Ready)
        assertEquals(2, fixture.devices.ensureCalls)
        assertEquals(2, fixture.devices.topUpCalls)
    }

    @Test
    fun concurrentForeground_isSerialized() = runTest {
        val fixture = Fixture(MessageRuntimeSettings(contentAuditMode = "e2ee"))
        fixture.lifecycle.onAuthenticated("account-a", "token")

        val first = async { fixture.lifecycle.onForeground() }
        val second = async { fixture.lifecycle.onForeground() }
        first.await()
        second.await()

        assertEquals(3, fixture.devices.ensureCalls)
        assertEquals(1, fixture.devices.maxConcurrent)
    }

    @Test
    fun pendingDevice_blocksE2eeRoute() = runTest {
        val fixture = Fixture(MessageRuntimeSettings(contentAuditMode = "e2ee"))
        fixture.devices.profile = fixture.devices.profile.copy(deviceStatus = "pending_approval")

        val error = runCatching { fixture.lifecycle.onAuthenticated("account-a", "token") }.exceptionOrNull()

        assertTrue(error is E2eeDeviceNotReadyException)
        assertTrue(fixture.lifecycle.status.value is E2eeSessionStatus.Blocked)
        assertTrue(runCatching { fixture.lifecycle.requireE2eeReady() }.isFailure)
    }

    @Test
    fun unknownRuntime_blocksWithoutInitializingDevice() = runTest {
        val fixture = Fixture(MessageRuntimeSettings(contentAuditMode = "future"))

        val error = runCatching { fixture.lifecycle.onAuthenticated("account-a", "token") }.exceptionOrNull()

        assertTrue(error is IllegalArgumentException)
        assertEquals(0, fixture.devices.ensureCalls)
        assertTrue(fixture.lifecycle.status.value is E2eeSessionStatus.Blocked)
    }

    @Test
    fun logoutClearsActiveAccountState() = runTest {
        val fixture = Fixture(MessageRuntimeSettings(contentAuditMode = "e2ee"))
        fixture.lifecycle.onAuthenticated("account-a", "token")

        fixture.lifecycle.onLogout()

        assertEquals(E2eeSessionStatus.SignedOut, fixture.lifecycle.status.value)
        assertTrue(fixture.blobs.load("account-a") == null)
        assertTrue(fixture.storage.readProfile("account-a") == null)
        assertTrue(fixture.storage.readMetadata("account-a", "direct-message") == null)
    }

    @Test
    fun accountSwitchClearsPreviousAccountBeforePreparingNext() = runTest {
        val fixture = Fixture(MessageRuntimeSettings())
        fixture.lifecycle.onAuthenticated("account-a", "token-a")

        fixture.lifecycle.onAuthenticated("account-b", "token-b")

        assertTrue(fixture.blobs.load("account-a") == null)
        assertTrue(fixture.storage.readProfile("account-a") == null)
        assertEquals(E2eeSessionStatus.Plaintext, fixture.lifecycle.status.value)
    }

    private class Fixture(runtime: MessageRuntimeSettings) {
        val settings = FakeSettingsRepository(runtime)
        val devices = FakeDevices()
        val blobs = InMemoryE2eeStateBlobStore()
        val storage = E2eeSecureStateStore(InMemoryE2eeStateCipher(), blobs) { true }
        val lifecycle = E2eeSessionLifecycle(settings, devices, storage, "Android Test")

        init {
            storage.write("account-a", byteArrayOf(1))
            storage.writeProfile("account-a", devices.profile)
            storage.writeMetadata("account-a", "direct-message", byteArrayOf(2))
        }
    }

    private class FakeSettingsRepository(runtime: MessageRuntimeSettings) : SettingsRepository {
        override val settings = MutableStateFlow(AppSettings(messageRuntime = runtime))
        override suspend fun refreshGeneralSettings(): AppSettings = settings.value
        override suspend fun setNotificationEnabled(enabled: Boolean) = Unit
        override suspend fun fetchDocument(kind: SettingsDocumentKind) = DocumentContent(kind.title, "")
    }

    private class FakeDevices : E2eeAppDeviceLifecycle {
        var profile =
            E2eeDeviceProfile(
                deviceId = "device-a",
                deviceLabel = "Android Test",
                registered = true,
                keyPackagePublished = true,
                deviceStatus = "active",
            )
        var ensureCalls = 0
        var topUpCalls = 0
        var concurrent = 0
        var maxConcurrent = 0

        override suspend fun ensureReady(accountId: String, deviceLabel: String, token: String): E2eeDeviceProfile {
            ensureCalls += 1
            concurrent += 1
            maxConcurrent = maxOf(maxConcurrent, concurrent)
            kotlinx.coroutines.yield()
            concurrent -= 1
            return profile
        }

        override suspend fun topUpKeyPackages(accountId: String, token: String): Int {
            topUpCalls += 1
            return 0
        }
    }
}
