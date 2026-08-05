package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.MessageRuntimeSettings
import com.redcode.im.androidapp.data.settings.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

sealed interface E2eeSessionStatus {
    data object SignedOut : E2eeSessionStatus
    data object Plaintext : E2eeSessionStatus
    data class Ready(val accountId: String, val deviceId: String) : E2eeSessionStatus
    data class Blocked(val message: String) : E2eeSessionStatus
}

interface E2eeAppDeviceLifecycle {
    suspend fun ensureReady(accountId: String, deviceLabel: String, token: String): E2eeDeviceProfile

    suspend fun topUpKeyPackages(accountId: String, token: String): Int
}

/** 账号级应用生命周期入口。未知 runtime 或设备异常会保留 Blocked 状态，供消息路由 fail closed。 */
class E2eeSessionLifecycle(
    private val settings: SettingsRepository,
    private val devices: E2eeAppDeviceLifecycle,
    private val secureState: E2eeSecureStateStore,
    private val deviceLabel: String,
) {
    private data class ActiveSession(val accountId: String, val token: String)

    private val mutex = Mutex()
    private val mutableStatus = MutableStateFlow<E2eeSessionStatus>(E2eeSessionStatus.SignedOut)
    val status = mutableStatus.asStateFlow()
    private var activeSession: ActiveSession? = null

    suspend fun onAuthenticated(accountId: String, token: String) = mutex.withLock {
        require(accountId.isNotBlank()) { "E2EE 账号标识不能为空" }
        require(token.isNotBlank()) { "E2EE 认证 token 不能为空" }
        activeSession
            ?.accountId
            ?.takeIf { it != accountId }
            ?.let(secureState::delete)
        activeSession = ActiveSession(accountId, token)
        refreshAndPrepare(activeSession!!)
    }

    suspend fun onForeground() = mutex.withLock {
        activeSession?.let { refreshAndPrepare(it) }
    }

    suspend fun onLogout() = mutex.withLock {
        val accountId = activeSession?.accountId
        activeSession = null
        if (accountId != null) secureState.delete(accountId)
        mutableStatus.value = E2eeSessionStatus.SignedOut
    }

    fun requireE2eeReady(): E2eeSessionStatus.Ready =
        status.value as? E2eeSessionStatus.Ready
            ?: throw E2eeDeviceNotReadyException(
                (status.value as? E2eeSessionStatus.Blocked)?.message ?: "当前设备未进入 E2EE ready 状态",
            )

    private suspend fun refreshAndPrepare(session: ActiveSession) {
        try {
            val runtime = settings.refreshGeneralSettings().messageRuntime.requireSupported()
            if (!runtime.isE2ee) {
                mutableStatus.value = E2eeSessionStatus.Plaintext
                return
            }
            val profile = devices.ensureReady(session.accountId, deviceLabel, session.token)
            if (profile.deviceStatus != "active") {
                throw E2eeDeviceNotReadyException("E2EE 设备状态为 ${profile.deviceStatus}，拒绝进入加密消息链")
            }
            devices.topUpKeyPackages(session.accountId, session.token)
            mutableStatus.value = E2eeSessionStatus.Ready(session.accountId, profile.deviceId)
        } catch (error: Exception) {
            mutableStatus.value = E2eeSessionStatus.Blocked(error.message ?: "E2EE 初始化失败")
            throw error
        }
    }
}

internal fun MessageRuntimeSettings.requireE2ee(): MessageRuntimeSettings =
    requireSupported().also { require(it.isE2ee) { "当前 message runtime 不是 E2EE" } }
