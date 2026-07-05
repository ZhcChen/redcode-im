package com.redcode.im.androidapp

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import org.junit.Rule
import org.junit.Test

class MainActivityTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun registerOpensChatList() {
        composeRule.onNodeWithTag("login-screen").assertIsDisplayed()
        composeRule.onNodeWithTag("toggle-auth-mode").performClick()
        composeRule.onNodeWithTag("account-input").performTextInput("androidtester")
        composeRule.onNodeWithTag("password-input").performTextInput("password1")
        ensureAgreementAccepted()
        composeRule.onNodeWithTag("auth-submit").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("chat-list").assertIsDisplayed()
    }

    @Test
    fun authRequiresAgreementAndShowsDocuments() {
        composeRule.onNodeWithTag("login-screen").assertIsDisplayed()
        ensureAgreementRejected()
        composeRule.onNodeWithTag("account-input").performTextInput("androidtester")
        composeRule.onNodeWithTag("password-input").performTextInput("password1")
        composeRule.onNodeWithTag("auth-submit").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("请勾选并阅读《用户协议》和《隐私协议》").assertIsDisplayed()

        composeRule.onNodeWithTag("user-agreement-link").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("document-dialog").assertIsDisplayed()
        composeRule.onNodeWithText("使用 RedCode IM", substring = true).assertIsDisplayed()
        composeRule.onNodeWithTag("document-close").performClick()
    }

    private fun ensureAgreementAccepted() {
        val toggle = composeRule.onNodeWithTag("agreement-toggle")
        runCatching { toggle.assertIsOn() }.onFailure {
            toggle.performClick()
            composeRule.waitForIdle()
            toggle.assertIsOn()
        }
    }

    private fun ensureAgreementRejected() {
        val toggle = composeRule.onNodeWithTag("agreement-toggle")
        runCatching { toggle.assertIsOff() }.onFailure {
            toggle.performClick()
            composeRule.waitForIdle()
            toggle.assertIsOff()
        }
    }
}
