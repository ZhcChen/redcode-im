package com.redcode.im.androidapp

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
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
        composeRule.onNodeWithTag("auth-submit").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("chat-list").assertIsDisplayed()
    }
}
