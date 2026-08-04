package com.redcode.im.androidapp.feature.permissions

enum class RuntimePermissionKind(
    private val recoverableMessage: String,
    private val permanentlyDeniedMessage: String,
) {
    Notifications(
        recoverableMessage = "通知权限已拒绝，可重新授权后接收新消息提醒。",
        permanentlyDeniedMessage = "通知权限已被系统阻止，请到系统设置中开启通知权限。",
    ),
    Microphone(
        recoverableMessage = "麦克风权限已拒绝，可重新授权后使用语音功能。",
        permanentlyDeniedMessage = "麦克风权限已被系统阻止，请到系统设置中开启麦克风权限。",
    ),
    ;

    fun prompt(permanentlyDenied: Boolean): PermissionRecoveryPrompt =
        PermissionRecoveryPrompt(
            message = if (permanentlyDenied) permanentlyDeniedMessage else recoverableMessage,
            actionLabel = if (permanentlyDenied) "打开设置" else "重新授权",
            opensAppSettings = permanentlyDenied,
        )
}

data class PermissionRecoveryPrompt(
    val message: String,
    val actionLabel: String,
    val opensAppSettings: Boolean,
)

data class PermissionRecoveryState(
    val deniedCount: Int = 0,
    val prompt: PermissionRecoveryPrompt? = null,
) {
    fun onGranted(): PermissionRecoveryState = PermissionRecoveryState()

    fun onDenied(
        kind: RuntimePermissionKind,
        shouldShowRationale: Boolean,
    ): PermissionRecoveryState {
        val nextDeniedCount = deniedCount + 1
        val permanentlyDenied = nextDeniedCount >= 2 || !shouldShowRationale
        return copy(
            deniedCount = nextDeniedCount,
            prompt = kind.prompt(permanentlyDenied),
        )
    }

    fun dismissPrompt(): PermissionRecoveryState = copy(prompt = null)
}
