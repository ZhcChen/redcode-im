package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.feature.permissions.PermissionRecoveryState
import com.redcode.im.androidapp.feature.permissions.RuntimePermissionKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionRecoveryTest {
    @Test
    fun firstRecoverableDenialShowsRetryPrompt() {
        val state =
            PermissionRecoveryState()
                .onDenied(RuntimePermissionKind.Microphone, shouldShowRationale = true)

        assertEquals(1, state.deniedCount)
        assertEquals("重新授权", state.prompt?.actionLabel)
        assertFalse(state.prompt!!.opensAppSettings)
        assertTrue(state.prompt!!.message.contains("麦克风权限已拒绝"))
    }

    @Test
    fun secondDenialRoutesToSystemSettings() {
        val state =
            PermissionRecoveryState()
                .onDenied(RuntimePermissionKind.Notifications, shouldShowRationale = true)
                .onDenied(RuntimePermissionKind.Notifications, shouldShowRationale = true)

        assertEquals(2, state.deniedCount)
        assertEquals("打开设置", state.prompt?.actionLabel)
        assertTrue(state.prompt!!.opensAppSettings)
        assertTrue(state.prompt!!.message.contains("系统设置"))
    }

    @Test
    fun doNotAskAgainRoutesToSystemSettingsImmediately() {
        val state =
            PermissionRecoveryState()
                .onDenied(RuntimePermissionKind.Notifications, shouldShowRationale = false)

        assertEquals(1, state.deniedCount)
        assertEquals("打开设置", state.prompt?.actionLabel)
        assertTrue(state.prompt!!.opensAppSettings)
    }

    @Test
    fun grantedAndDismissResetPrompt() {
        val denied =
            PermissionRecoveryState()
                .onDenied(RuntimePermissionKind.Microphone, shouldShowRationale = true)

        assertNull(denied.dismissPrompt().prompt)
        assertEquals(PermissionRecoveryState(), denied.onGranted())
    }
}
