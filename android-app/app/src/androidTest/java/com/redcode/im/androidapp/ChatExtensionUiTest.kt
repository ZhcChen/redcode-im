package com.redcode.im.androidapp

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.ui.theme.RedCodeTheme
import org.junit.Rule
import org.junit.Test

class ChatExtensionUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun chatDetailEmojiPanelInsertsDraft() {
        val viewModel = viewModel()

        composeRule.setContent {
            RedCodeTheme {
                ChatDetailScreen(summary = summary(), viewModel = viewModel, onBack = {})
            }
        }

        composeRule.onNodeWithTag("emoji-toggle").performClick()
        composeRule.onNodeWithTag("emoji-panel").assertIsDisplayed()
        composeRule.onNodeWithTag("emoji-item-0").performClick()

        composeRule.onNodeWithTag("message-input").assertTextContains("😀")
    }

    @Test
    fun chatDetailStickerPanelCanSendDefaultSticker() {
        val viewModel = viewModel()

        composeRule.setContent {
            RedCodeTheme {
                ChatDetailScreen(summary = summary(), viewModel = viewModel, onBack = {})
            }
        }

        composeRule.onNodeWithTag("sticker-toggle").performClick()
        composeRule.onNodeWithTag("sticker-panel").assertIsDisplayed()
        composeRule.onNodeWithTag("sticker-item-redcode-ok").performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithText("[图片]", substring = true).assertIsDisplayed()
    }

    @Test
    fun chatDetailSettingsToggleLocalPreferences() {
        val viewModel = viewModel()

        composeRule.setContent {
            RedCodeTheme {
                ChatDetailScreen(summary = summary(), viewModel = viewModel, onBack = {})
            }
        }

        composeRule.onNodeWithTag("chat-background-cycle").performClick()
        composeRule.onNodeWithTag("chat-font-cycle").performClick()
        composeRule.onNodeWithTag("chat-enter-to-send-toggle").performClick()
        composeRule.onNodeWithTag("chat-auto-download-toggle").performClick()

        composeRule.onNodeWithText("背景：暖色").assertIsDisplayed()
        composeRule.onNodeWithText("字体：120%").assertIsDisplayed()
        composeRule.onNodeWithText("回车发送：开").assertIsDisplayed()
        composeRule.onNodeWithText("自动下载：开").assertIsDisplayed()
    }

    private fun viewModel(): ChatDetailViewModel =
        ChatDetailViewModel(
            chatRepository = InMemoryChatRepository(),
            roomId = "room-general",
            currentUserId = "user-me",
            currentUserName = "Me",
        )

    private fun summary(): ChatSummary =
        ChatSummary(
            roomId = "room-general",
            title = "聊天扩展测试",
            roomType = ChatRoomType.Group,
            lastMessagePreview = "",
        )
}
