package com.redcode.im.androidapp

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.redcode.im.androidapp.feature.permissions.PermissionRecoveryPrompt
import com.redcode.im.androidapp.ui.theme.RedCodeTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class PermissionRecoveryBannerTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun bannerShowsRecoveryActionAndDismiss() {
        var actionClicks = 0
        var dismissClicks = 0

        composeRule.setContent {
            RedCodeTheme {
                PermissionRecoveryBanner(
                    prompt =
                        PermissionRecoveryPrompt(
                            message = "通知权限已拒绝，可重新授权后接收新消息提醒。",
                            actionLabel = "重新授权",
                            opensAppSettings = false,
                        ),
                    testTagPrefix = "notification-permission",
                    onAction = { actionClicks += 1 },
                    onDismiss = { dismissClicks += 1 },
                )
            }
        }

        composeRule.onNodeWithTag("notification-permission-banner").assertIsDisplayed()
        composeRule.onNodeWithText("通知权限已拒绝", substring = true).assertIsDisplayed()
        composeRule.onNodeWithTag("notification-permission-action").performClick()
        composeRule.onNodeWithTag("notification-permission-dismiss").performClick()

        assertEquals(1, actionClicks)
        assertEquals(1, dismissClicks)
    }
}
