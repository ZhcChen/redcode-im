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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
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
import androidx.compose.runtime.DisposableEffect
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
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.di.AppContainer
import com.redcode.im.androidapp.feature.auth.AuthMode
import com.redcode.im.androidapp.feature.auth.AuthViewModel
import com.redcode.im.androidapp.feature.chat.ChatDetailViewModel
import com.redcode.im.androidapp.feature.chat.ChatListViewModel
import com.redcode.im.androidapp.feature.contacts.ContactsViewModel
import com.redcode.im.androidapp.feature.settings.SettingsViewModel
import java.time.Instant

enum class MainTab(val label: String) {
    Chats("聊天"),
    Contacts("联系人"),
    Settings("设置"),
}

@Composable
fun RedCodeApp(container: AppContainer) {
    val authViewModel =
        remember {
            AuthViewModel(
                authRepository = container.authRepository,
                userPreferenceStore = container.userPreferenceStore,
                logoutCleanup = container::clearLocalSessionState,
            )
        }
    val settingsViewModel = remember { SettingsViewModel(container.settingsRepository) }
    val authState by authViewModel.uiState.collectAsStateWithLifecycle()
    val documentState by settingsViewModel.document.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        if (authState.session == null) {
            LoginScreen(
                viewModel = authViewModel,
                onOpenDocument = settingsViewModel::loadDocument,
            )
        } else {
            MainShell(
                container = container,
                authViewModel = authViewModel,
                settingsViewModel = settingsViewModel,
                currentUserId = authState.session!!.user.id,
                currentUserName = authState.session!!.user.displayName,
                accessToken = authState.session!!.tokens.accessToken,
            )
        }
        if (documentState.kind != null) {
            SettingsDocumentDialog(
                state = documentState,
                onDismiss = settingsViewModel::dismissDocument,
            )
        }
    }
}

@Composable
fun LoginScreen(viewModel: AuthViewModel, onOpenDocument: (SettingsDocumentKind) -> Unit) {
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
        Spacer(modifier = Modifier.height(12.dp))
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Checkbox(
                checked = uiState.hasAcceptedTerms,
                onCheckedChange = viewModel::setAcceptedTerms,
                modifier = Modifier.testTag("agreement-toggle"),
            )
            Column {
                Text("我已阅读并同意协议", style = MaterialTheme.typography.bodyMedium)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(
                        onClick = { onOpenDocument(SettingsDocumentKind.UserAgreement) },
                        modifier = Modifier.testTag("user-agreement-link"),
                    ) {
                        Text("用户协议")
                    }
                    TextButton(
                        onClick = { onOpenDocument(SettingsDocumentKind.PrivacyPolicy) },
                        modifier = Modifier.testTag("privacy-policy-link"),
                    ) {
                        Text("隐私协议")
                    }
                }
            }
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
    settingsViewModel: SettingsViewModel,
    currentUserId: String,
    currentUserName: String,
    accessToken: String,
) {
    var selectedTab by remember { mutableStateOf(MainTab.Chats) }
    var selectedChat by remember { mutableStateOf<ChatSummary?>(null) }
    val chatListViewModel = remember { ChatListViewModel(container.chatRepository) }
    val contactsViewModel = remember { ContactsViewModel(container.contactsRepository) }
    val realtimeChats by chatListViewModel.chats.collectAsStateWithLifecycle()

    LaunchedEffect(accessToken) {
        container.webSocketClient?.connect(accessToken)
    }
    LaunchedEffect(realtimeChats) {
        container.webSocketClient?.ensureRoomsSubscribed(realtimeChats.map { it.roomId }, pruneMissing = true)
    }
    container.webSocketClient?.let { client ->
        val realtimeEvent by client.events.collectAsStateWithLifecycle()
        LaunchedEffect(realtimeEvent) {
            realtimeEvent?.let { container.realtimeEventProcessor?.handle(it) }
        }
    }
    DisposableEffect(container.webSocketClient) {
        onDispose {
            container.webSocketClient?.disconnect()
        }
    }

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
                    MainTab.Contacts ->
                        ContactsScreen(
                            viewModel = contactsViewModel,
                            onOpenPrivateChat = { contact, roomId ->
                                selectedChat =
                                    ChatSummary(
                                        roomId = roomId,
                                        title = contact.displayName,
                                        roomType = ChatRoomType.Direct,
                                        lastMessagePreview = "暂无消息",
                                        updatedAt = Instant.now(),
                                    )
                            },
                        )
                    MainTab.Settings -> SettingsScreen(settingsViewModel, authViewModel, container.environment.apiBaseUrl)
                }
            }
        }
    }
}

@Composable
fun ChatListScreen(viewModel: ChatListViewModel, onOpenChat: (ChatSummary) -> Unit) {
    val chats by viewModel.chats.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    Column(modifier = Modifier.fillMaxSize().testTag("chat-list")) {
        Header(title = "聊天")
        errorMessage?.let {
            Text(text = it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp))
        }
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
                        if (chat.isPinned) Text("置顶", color = MaterialTheme.colorScheme.primary)
                        if (chat.isMuted) Text(" 免打扰", color = MaterialTheme.colorScheme.secondary)
                        if (chat.unreadCount > 0) Text("未读 ${chat.unreadCount}", color = MaterialTheme.colorScheme.primary)
                    }
                    Text(chat.lastMessagePreview, style = MaterialTheme.typography.bodyMedium)
                    Row {
                        TextButton(onClick = { viewModel.togglePinned(chat) }) {
                            Text(if (chat.isPinned) "取消置顶" else "置顶")
                        }
                        TextButton(onClick = { viewModel.toggleMuted(chat) }) {
                            Text(if (chat.isMuted) "取消免打扰" else "免打扰")
                        }
                    }
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
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::onSearchQueryChange,
                label = { Text("搜索本地消息") },
                singleLine = true,
                modifier = Modifier.weight(1f).testTag("message-search-input"),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Button(
                onClick = viewModel::searchMessages,
                enabled = !uiState.isSearching,
                modifier = Modifier.testTag("message-search-button"),
            ) {
                Text(if (uiState.isSearching) "搜索中" else "搜索")
            }
            if (uiState.searchQuery.isNotBlank() || uiState.searchResults.isNotEmpty()) {
                TextButton(onClick = viewModel::clearSearch) { Text("清空") }
            }
        }
        if (uiState.searchQuery.isNotBlank()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .testTag("message-search-results"),
            ) {
                Text("本地搜索结果 ${uiState.searchResults.size}", style = MaterialTheme.typography.titleSmall)
                uiState.searchResults.forEach { result ->
                    Text("${result.senderName}: ${result.text}", style = MaterialTheme.typography.bodySmall)
                }
            }
            HorizontalDivider()
        }
        Column(modifier = Modifier.weight(1f).padding(16.dp)) {
            if (uiState.messages.isNotEmpty() && uiState.hasOlderMessages) {
                TextButton(
                    onClick = viewModel::loadOlderMessages,
                    enabled = !uiState.isLoadingOlder,
                    modifier = Modifier.testTag("load-older-messages"),
                ) {
                    Text(if (uiState.isLoadingOlder) "加载中" else "加载更早")
                }
            }
            uiState.messages.forEach { message ->
                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (message.isPinned) {
                            Text("置顶 ", color = MaterialTheme.colorScheme.primary)
                        }
                        Text("${message.senderName}: ${message.text}")
                        Spacer(modifier = Modifier.width(8.dp))
                        when (message.status) {
                            MessageStatus.Pending -> Text("发送中", style = MaterialTheme.typography.bodySmall)
                            MessageStatus.Failed ->
                                TextButton(
                                    onClick = { viewModel.resendMessage(message.id) },
                                    modifier = Modifier.testTag("resend-message-${message.id}"),
                                ) {
                                    Text("发送失败，重试")
                                }
                            MessageStatus.Sent -> Unit
                        }
                    }
                    message.quotedMessage?.let { quote ->
                        Text(
                            text = "引用 ${quote.senderName}: ${quote.text}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    if (message.reactions.isNotEmpty()) {
                        Text(
                            text = message.reactions.joinToString(" ") { "${it.reactionKey} ${it.count}" },
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    if (!message.id.startsWith("local-") && !message.isDeleted) {
                        Row {
                            TextButton(onClick = { viewModel.deleteMessage(message.id) }) {
                                Text("删除")
                            }
                            TextButton(onClick = { viewModel.toggleMessagePinned(message) }) {
                                Text(if (message.isPinned) "取消置顶" else "置顶")
                            }
                            TextButton(onClick = { viewModel.toggleThumbReaction(message) }) {
                                Text(if (message.reactions.any { it.reactionKey == "👍" && it.hasSelf }) "取消👍" else "👍")
                            }
                            TextButton(onClick = { viewModel.quoteMessage(message) }) {
                                Text("引用")
                            }
                        }
                    }
                }
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
        uiState.quotedMessage?.let { quote ->
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "引用 ${quote.senderName}: ${quote.text}",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.weight(1f).testTag("quoted-message-preview"),
                )
                TextButton(onClick = viewModel::clearQuote) {
                    Text("取消")
                }
            }
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
fun ContactsScreen(viewModel: ContactsViewModel, onOpenPrivateChat: (Contact, String) -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedContact by remember { mutableStateOf<Contact?>(null) }
    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).testTag("contacts-screen")) {
        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "联系人",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = viewModel::refresh, enabled = !uiState.isRefreshing, modifier = Modifier.testTag("contacts-refresh")) {
                Text(if (uiState.isRefreshing) "刷新中" else "刷新")
            }
        }
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = uiState.query,
                onValueChange = viewModel::onQueryChange,
                label = { Text("搜索账号") },
                modifier = Modifier.weight(1f).testTag("contact-search"),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Button(onClick = viewModel::search, enabled = !uiState.isSearching, modifier = Modifier.testTag("contact-search-submit")) {
                Text(if (uiState.isSearching) "搜索中" else "搜索")
            }
        }
        if (uiState.errorMessage != null) {
            Text(
                text = uiState.errorMessage!!,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(horizontal = 16.dp).testTag("contacts-error"),
            )
        }
        if (uiState.searchResults.isNotEmpty()) {
            Text("搜索结果", modifier = Modifier.padding(horizontal = 16.dp), fontWeight = FontWeight.SemiBold)
            uiState.searchResults.forEach { contact ->
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(contact.displayName, fontWeight = FontWeight.SemiBold)
                        Text(contact.accountName, style = MaterialTheme.typography.bodyMedium)
                    }
                    Button(
                        onClick = { viewModel.addContact(contact) },
                        enabled = !uiState.isSubmitting,
                        modifier = Modifier.testTag("send-friend-request-${contact.userId}"),
                    ) {
                        Text("添加")
                    }
                }
            }
            HorizontalDivider()
        }
        Text(
            text = "新的朋友 · ${uiState.incomingRequests.count { it.status == FriendRequestStatus.Pending }} 条待处理",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            fontWeight = FontWeight.SemiBold,
        )
        if (uiState.incomingRequests.isEmpty()) {
            Text("暂无好友请求", modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
        } else {
            uiState.incomingRequests.forEach { request ->
                FriendRequestRow(
                    request = request,
                    isSubmitting = uiState.isSubmitting,
                    onAccept = { viewModel.respondRequest(request.id, accept = true) },
                    onDecline = { viewModel.respondRequest(request.id, accept = false) },
                )
                HorizontalDivider()
            }
        }
        if (uiState.outgoingRequests.isNotEmpty()) {
            Text("已发送申请", modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp), fontWeight = FontWeight.SemiBold)
            uiState.outgoingRequests.forEach { request ->
                Text(
                    text = "${request.counterpartyDisplayName} · 等待对方验证",
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
            HorizontalDivider()
        }
        Text(
            text = "联系人 · ${uiState.contacts.size} 人",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            fontWeight = FontWeight.SemiBold,
        )
        if (uiState.contacts.isEmpty()) {
            Text("暂无联系人，搜索账号添加好友。", modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
        }
        uiState.contacts.forEach { contact ->
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { selectedContact = contact }, modifier = Modifier.weight(1f).testTag("contact-row-${contact.userId}")) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(contact.displayName, fontWeight = FontWeight.SemiBold)
                        Text(contact.accountName, style = MaterialTheme.typography.bodyMedium)
                    }
                }
                Button(
                    onClick = {
                        viewModel.openPrivateChat(contact) { roomId ->
                            onOpenPrivateChat(contact, roomId)
                        }
                    },
                    enabled = !uiState.isSubmitting,
                    modifier = Modifier.testTag("open-private-chat-${contact.userId}"),
                ) {
                    Text("私聊")
                }
            }
            HorizontalDivider()
        }
    }
    selectedContact?.let { contact ->
        ContactDetailDialog(
            contact = contact,
            isSubmitting = uiState.isSubmitting,
            onDismiss = { selectedContact = null },
            onOpenPrivateChat = {
                viewModel.openPrivateChat(contact) { roomId ->
                    selectedContact = null
                    onOpenPrivateChat(contact, roomId)
                }
            },
        )
    }
}

@Composable
private fun FriendRequestRow(
    request: FriendRequest,
    isSubmitting: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(request.counterpartyDisplayName, fontWeight = FontWeight.SemiBold)
        Text(request.message ?: "请求添加你为好友", style = MaterialTheme.typography.bodyMedium)
        if (request.status == FriendRequestStatus.Pending && request.isIncoming) {
            Row(modifier = Modifier.padding(top = 8.dp)) {
                Button(onClick = onAccept, enabled = !isSubmitting, modifier = Modifier.testTag("accept-request-${request.id}")) {
                    Text("同意")
                }
                Spacer(modifier = Modifier.width(8.dp))
                TextButton(onClick = onDecline, enabled = !isSubmitting, modifier = Modifier.testTag("decline-request-${request.id}")) {
                    Text("拒绝")
                }
            }
        } else {
            Text(request.status.name, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun ContactDetailDialog(
    contact: Contact,
    isSubmitting: Boolean,
    onDismiss: () -> Unit,
    onOpenPrivateChat: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("联系人详情") },
        text = {
            Column(modifier = Modifier.testTag("contact-detail")) {
                Text(contact.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text("账号：${contact.accountName}")
                Text("用户ID：${contact.userId}")
            }
        },
        confirmButton = {
            Button(onClick = onOpenPrivateChat, enabled = !isSubmitting, modifier = Modifier.testTag("contact-detail-open-chat")) {
                Text("发消息")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("关闭")
            }
        },
    )
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
        TextButton(
            onClick = { viewModel.loadDocument(SettingsDocumentKind.UserAgreement) },
            modifier = Modifier.padding(horizontal = 16.dp).testTag("settings-user-agreement"),
        ) {
            Text("用户协议")
        }
        TextButton(
            onClick = { viewModel.loadDocument(SettingsDocumentKind.PrivacyPolicy) },
            modifier = Modifier.padding(horizontal = 16.dp).testTag("settings-privacy-policy"),
        ) {
            Text("隐私协议")
        }
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = authViewModel::logout, modifier = Modifier.padding(horizontal = 16.dp).testTag("logout")) {
            Text("退出登录")
        }
    }
}

@Composable
private fun SettingsDocumentDialog(
    state: com.redcode.im.androidapp.feature.settings.SettingsDocumentUiState,
    onDismiss: () -> Unit,
) {
    val title = state.document?.title ?: state.kind?.title.orEmpty()
    val body =
        when {
            state.isLoading -> "加载中..."
            state.errorMessage != null -> state.errorMessage
            else -> state.document?.content.orEmpty()
        }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Text(
                text = body,
                modifier =
                    Modifier
                        .testTag("document-dialog")
                        .verticalScroll(rememberScrollState()),
            )
        },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("document-close")) {
                Text("关闭")
            }
        },
    )
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
