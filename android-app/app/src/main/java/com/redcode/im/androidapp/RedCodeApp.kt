package com.redcode.im.androidapp

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.di.AppContainer
import com.redcode.im.androidapp.feature.auth.AuthMode
import com.redcode.im.androidapp.feature.auth.AuthViewModel
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.feature.chat.ChatListViewModel
import com.redcode.im.androidapp.feature.contacts.ContactsViewModel
import com.redcode.im.androidapp.feature.settings.SettingsViewModel

enum class MainTab(val label: String) {
    Chats("聊天"),
    Contacts("联系人"),
    Settings("设置"),
}

@Composable
fun RedCodeApp(container: AppContainer) {
    val authViewModel = remember { AuthViewModel(container.authRepository) }
    val authState by authViewModel.uiState.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        if (authState.session == null) {
            LoginScreen(viewModel = authViewModel)
        } else {
            MainShell(
                container = container,
                authViewModel = authViewModel,
                currentUserId = authState.session!!.user.id,
                currentUserName = authState.session!!.user.displayName,
            )
        }
    }
}

@Composable
fun LoginScreen(viewModel: AuthViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(24.dp)
                .testTag("login-screen"),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(72.dp))
        Text(text = "RedCode IM", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text(text = "原生 Android 迁移版", style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.height(32.dp))
        OutlinedTextField(
            value = uiState.accountName,
            onValueChange = viewModel::onAccountNameChange,
            label = { Text("账号") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("account-input"),
        )
        Spacer(modifier = Modifier.height(12.dp))
        OutlinedTextField(
            value = uiState.password,
            onValueChange = viewModel::onPasswordChange,
            label = { Text("密码") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth().testTag("password-input"),
        )
        if (uiState.errorMessage != null) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(text = uiState.errorMessage!!, color = MaterialTheme.colorScheme.error)
        }
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            onClick = viewModel::submit,
            enabled = !uiState.isLoading,
            modifier = Modifier.fillMaxWidth().testTag("auth-submit"),
        ) {
            Text(if (uiState.mode == AuthMode.Login) "登录" else "注册并登录")
        }
        TextButton(onClick = viewModel::toggleMode, modifier = Modifier.testTag("toggle-auth-mode")) {
            Text(if (uiState.mode == AuthMode.Login) "没有账号？去注册" else "已有账号？去登录")
        }
    }
}

@Composable
private fun MainShell(
    container: AppContainer,
    authViewModel: AuthViewModel,
    currentUserId: String,
    currentUserName: String,
) {
    var selectedTab by remember { mutableStateOf(MainTab.Chats) }
    var selectedChat by remember { mutableStateOf<ChatSummary?>(null) }
    val chatListViewModel = remember { ChatListViewModel(container.chatRepository) }
    val contactsViewModel = remember { ContactsViewModel(container.contactsRepository) }
    val settingsViewModel = remember { SettingsViewModel(container.settingsRepository) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                MainTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = {
                            selectedTab = tab
                            selectedChat = null
                        },
                        label = { Text(tab.label) },
                        icon = { Text(tab.label.take(1)) },
                    )
                }
            }
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            if (selectedChat != null) {
                ChatDetailScreen(
                    summary = selectedChat!!,
                    viewModel =
                        remember(selectedChat!!.roomId) {
                            ChatDetailViewModel(
                                chatRepository = container.chatRepository,
                                roomId = selectedChat!!.roomId,
                                currentUserId = currentUserId,
                                currentUserName = currentUserName,
                            )
                        },
                    onBack = { selectedChat = null },
                )
            } else {
                when (selectedTab) {
                    MainTab.Chats -> ChatListScreen(chatListViewModel, onOpenChat = { selectedChat = it })
                    MainTab.Contacts -> ContactsScreen(contactsViewModel)
                    MainTab.Settings -> SettingsScreen(settingsViewModel, authViewModel, container.environment.apiBaseUrl)
                }
            }
        }
    }
}

@Composable
fun ChatListScreen(viewModel: ChatListViewModel, onOpenChat: (ChatSummary) -> Unit) {
    val chats by viewModel.chats.collectAsStateWithLifecycle()
    Column(modifier = Modifier.fillMaxSize().testTag("chat-list")) {
        Header(title = "聊天")
        chats.forEach { chat ->
            TextButton(
                onClick = { onOpenChat(chat) },
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(chat.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.width(8.dp))
                        if (chat.unreadCount > 0) Text("未读 ${chat.unreadCount}", color = MaterialTheme.colorScheme.primary)
                    }
                    Text(chat.lastMessagePreview, style = MaterialTheme.typography.bodyMedium)
                }
            }
            HorizontalDivider()
        }
    }
}

@Composable
fun ChatDetailScreen(summary: ChatSummary, viewModel: ChatDetailViewModel, onBack: () -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        viewModel.markRead()
    }
    Column(modifier = Modifier.fillMaxSize().testTag("chat-detail")) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("返回") }
            Text(summary.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        HorizontalDivider()
        Column(modifier = Modifier.weight(1f).padding(16.dp)) {
            uiState.messages.forEach { message ->
                Text("${message.senderName}: ${message.text}")
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
        if (uiState.errorMessage != null) {
            Text(
                text = uiState.errorMessage!!,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = uiState.draft,
                onValueChange = viewModel::onDraftChange,
                label = { Text("输入消息") },
                modifier = Modifier.weight(1f).testTag("message-input"),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Button(onClick = viewModel::sendDraft, modifier = Modifier.testTag("send-message")) {
                Text("发送")
            }
        }
    }
}

@Composable
fun ContactsScreen(viewModel: ContactsViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Column(modifier = Modifier.fillMaxSize().testTag("contacts-screen")) {
        Header(title = "联系人")
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = uiState.query,
                onValueChange = viewModel::onQueryChange,
                label = { Text("搜索账号") },
                modifier = Modifier.weight(1f).testTag("contact-search"),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Button(onClick = viewModel::search) { Text("搜索") }
        }
        if (uiState.searchResults.isNotEmpty()) {
            Text("搜索结果", modifier = Modifier.padding(horizontal = 16.dp), fontWeight = FontWeight.SemiBold)
            uiState.searchResults.forEach { contact ->
                TextButton(onClick = { viewModel.addContact(contact) }, modifier = Modifier.fillMaxWidth()) {
                    Text("${contact.displayName} / ${contact.accountName}")
                }
            }
            HorizontalDivider()
        }
        uiState.contacts.forEach { contact ->
            Text(
                text = "${contact.displayName} (${contact.accountName})",
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            )
            HorizontalDivider()
        }
    }
}

@Composable
fun SettingsScreen(viewModel: SettingsViewModel, authViewModel: AuthViewModel, apiBaseUrl: String) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    Column(modifier = Modifier.fillMaxSize().testTag("settings-screen")) {
        Header(title = "设置")
        Text("API: $apiBaseUrl", modifier = Modifier.padding(16.dp))
        Text("通知: ${if (settings.notificationEnabled) "已开启" else "已关闭"}", modifier = Modifier.padding(16.dp))
        Button(onClick = viewModel::toggleNotification, modifier = Modifier.padding(horizontal = 16.dp)) {
            Text("切换通知")
        }
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = authViewModel::logout, modifier = Modifier.padding(horizontal = 16.dp).testTag("logout")) {
            Text("退出登录")
        }
    }
}

@Composable
private fun Header(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.headlineSmall,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.fillMaxWidth().padding(16.dp),
    )
}
