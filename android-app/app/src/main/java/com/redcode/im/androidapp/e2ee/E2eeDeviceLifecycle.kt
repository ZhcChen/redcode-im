package com.redcode.im.androidapp.e2ee

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred

class E2eeDeviceNotReadyException(message: String) : Exception(message)

/**
 * 设备注册与 KeyPackage 低水位补充（对齐 H5 E2eeDeviceLifecycle）：
 * - ensureReady：首设备初始化/恢复公开材料 → 服务端注册 → 首包发布；
 *   pending_approval 设备在批准前不发布 KeyPackage
 * - topUpKeyPackages：账号级单飞、低水位补充、失败 60s 退避
 */
class E2eeDeviceLifecycle(
    private val storage: E2eeSecureStateStore,
    private val mlsApi: E2eeMlsApi,
    private val core: E2eeCommandClient = E2eeCommandClient(),
    private val newDeviceId: () -> String = { UUID.randomUUID().toString() },
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : E2eeDirectDeviceLifecycle {
    private val replenishLocks = ConcurrentHashMap<String, Deferred<Int>>()
    private val nextRetryAt = ConcurrentHashMap<String, Long>()

    override suspend fun ensureReady(
        accountId: String,
        deviceLabel: String,
        token: String,
    ): E2eeDeviceProfile {
        val state = storage.read(accountId)
        var profile = storage.readProfile(accountId)
        if (state != null && profile == null) {
            throw E2eeDeviceNotReadyException("E2EE 设备状态不完整，拒绝重新生成身份")
        }
        if (state == null && profile?.registered == true) {
            throw E2eeDeviceNotReadyException("E2EE 已注册设备状态缺失，拒绝重新生成身份")
        }

        val material: E2eeRegistrationMaterial
        var currentState = state
        if (currentState == null) {
            val rootPublicKey = mlsApi.fetchRootIdentityOrNull(accountId, token)
            profile =
                profile
                    ?: E2eeDeviceProfile(
                        deviceId = newDeviceId(),
                        deviceLabel = deviceLabel,
                    )
            storage.writeProfile(accountId, profile)
            val result = core.initialize("$accountId/${profile.deviceId}", rootPublicKey)
            material = E2eeRegistrationMaterial.fromInitialize(result)
            currentState = material.state
            storage.write(accountId, currentState)
        } else {
            material = E2eeRegistrationMaterial.fromPublicMaterial(core.publicMaterial(currentState))
        }

        if (profile == null) throw E2eeDeviceNotReadyException("E2EE 设备档案缺失")
        var readyProfile = profile

        if (!readyProfile.registered) {
            val status = mlsApi.registerDevice(readyProfile.deviceId, readyProfile.deviceLabel, material, token)
            if (status == "pending_approval") {
                readyProfile =
                    readyProfile.copy(
                        registered = true,
                        keyPackagePublished = false,
                        deviceStatus = "pending_approval",
                    )
                storage.writeProfile(accountId, readyProfile)
                return readyProfile
            }
            readyProfile = readyProfile.copy(registered = true, deviceStatus = "active")
            storage.writeProfile(accountId, readyProfile)
        }

        if (readyProfile.deviceStatus == "pending_approval") {
            val current = mlsApi.listDevices(token).find { it.id == readyProfile.deviceId }
            if (current?.status != "active") return readyProfile
            readyProfile = readyProfile.copy(deviceStatus = "active")
            storage.writeProfile(accountId, readyProfile)
        }

        if (readyProfile.deviceStatus != "pending_approval" && !readyProfile.keyPackagePublished) {
            val generated = core.generateKeyPackage(currentState)
            storage.write(accountId, generated.field(0))
            mlsApi.publishKeyPackages(readyProfile.deviceId, listOf(generated.field(1)), token)
            readyProfile =
                readyProfile.copy(
                    keyPackagePublished = true,
                    deviceStatus = "active",
                )
            storage.writeProfile(accountId, readyProfile)
        }
        return readyProfile
    }

    /** 账号级互斥的低水位补充；失败进入退避窗口，不阻塞已建立房间的消息链。 */
    suspend fun topUpKeyPackages(accountId: String, token: String): Int {
        replenishLocks[accountId]?.let { return it.await() }
        val deferred = CompletableDeferred<Int>()
        val prior = replenishLocks.putIfAbsent(accountId, deferred)
        if (prior != null) return prior.await()
        try {
            val inserted = doTopUp(accountId, token)
            deferred.complete(inserted)
            return inserted
        } catch (e: Exception) {
            deferred.completeExceptionally(e)
            throw e
        } finally {
            replenishLocks.remove(accountId)
        }
    }

    private suspend fun doTopUp(accountId: String, token: String): Int {
        val profile = storage.readProfile(accountId)
        if (profile == null || !profile.registered || profile.deviceStatus == "pending_approval" || !profile.keyPackagePublished) {
            if (profile?.deviceStatus == "pending_approval") {
                throw E2eeDeviceNotReadyException("E2EE 设备待批准，批准后才能补充 KeyPackage")
            }
            throw E2eeDeviceNotReadyException("E2EE 设备未完成初始化，无法补充 KeyPackage")
        }
        val retryAt = nextRetryAt[accountId]
        if (retryAt != null && nowMillis() < retryAt) return 0

        val inventory = mlsApi.fetchKeyPackageInventory(profile.deviceId, token)
        if (inventory.available >= KEY_PACKAGE_LOW_WATERMARK) {
            nextRetryAt.remove(accountId)
            return 0
        }
        val needed = minOf(KEY_PACKAGE_TARGET - inventory.available, KEY_PACKAGE_BATCH_LIMIT)
        if (needed <= 0) {
            nextRetryAt.remove(accountId)
            return 0
        }

        return try {
            var state = storage.read(accountId)
                ?: throw E2eeDeviceNotReadyException("E2EE 设备状态缺失")
            val keyPackages = mutableListOf<ByteArray>()
            repeat(needed) {
                val generated = core.generateKeyPackage(state)
                state = generated.field(0)
                keyPackages += generated.field(1)
            }
            storage.write(accountId, state)
            val inserted = mlsApi.publishKeyPackages(profile.deviceId, keyPackages, token)
            nextRetryAt.remove(accountId)
            inserted
        } catch (e: Exception) {
            nextRetryAt[accountId] = nowMillis() + REPLENISH_RETRY_AFTER_MS
            throw e
        }
    }

    companion object {
        private const val KEY_PACKAGE_LOW_WATERMARK = 10
        private const val KEY_PACKAGE_TARGET = 40
        private const val KEY_PACKAGE_BATCH_LIMIT = 20
        private const val REPLENISH_RETRY_AFTER_MS = 60_000L
    }
}
