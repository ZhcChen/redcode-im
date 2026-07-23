package com.redcode.im.androidapp.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.StickerItem
import com.redcode.im.androidapp.core.model.StickerPack
import com.redcode.im.androidapp.core.model.attachmentFileName
import com.redcode.im.androidapp.core.model.chatBackgroundOptions
import com.redcode.im.androidapp.core.model.redCodeBuiltInEmoji
import com.redcode.im.androidapp.core.model.redCodeDefaultStickerPacks
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.emoji.EmojiRepository
import com.redcode.im.androidapp.data.preferences.ChatPreferenceStore
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ChatDetailFormState(
    val draft: String = "",
    val errorMessage: String? = null,
    val isLoadingOlder: Boolean = false,
    val hasOlderMessages: Boolean = true,
    val quotedMessage: ChatMessage? = null,
    val searchQuery: String = "",
    val searchResults: List<ChatMessage> = emptyList(),
    val isSearching: Boolean = false,
    val isUploadingAttachment: Boolean = false,
    val attachmentCacheStatus: Map<String, String> = emptyMap(),
    val audioPlaybackStatus: Map<String, AudioPlaybackState> = emptyMap(),
    val isEmojiPanelVisible: Boolean = false,
    val isStickerPanelVisible: Boolean = false,
    val isLoadingStickers: Boolean = false,
    val stickerPacks: List<StickerPack> = redCodeDefaultStickerPacks,
)

data class ChatDetailUiState(
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val errorMessage: String? = null,
    val isLoadingOlder: Boolean = false,
    val hasOlderMessages: Boolean = true,
    val quotedMessage: ChatMessage? = null,
    val searchQuery: String = "",
    val searchResults: List<ChatMessage> = emptyList(),
    val isSearching: Boolean = false,
    val isUploadingAttachment: Boolean = false,
    val attachmentCacheStatus: Map<String, String> = emptyMap(),
    val audioPlaybackStatus: Map<String, AudioPlaybackState> = emptyMap(),
    val isEmojiPanelVisible: Boolean = false,
    val isStickerPanelVisible: Boolean = false,
    val isLoadingStickers: Boolean = false,
    val builtInEmoji: List<String> = redCodeBuiltInEmoji,
    val stickerPacks: List<StickerPack> = redCodeDefaultStickerPacks,
    val chatPreferences: ChatRoomPreferences = ChatRoomPreferences(),
)

class ChatDetailViewModel(
    private val chatRepository: ChatRepository,
    private val roomId: String,
    private val currentUserId: String,
    private val currentUserName: String,
    private val audioPlaybackController: AudioPlaybackController = NoopAudioPlaybackController,
    private val chatPreferenceStore: ChatPreferenceStore = InMemoryUserPreferenceStore(),
    private val emojiRepository: EmojiRepository? = null,
) : ViewModel() {
    private val formState = MutableStateFlow(ChatDetailFormState())
    private val autoDownloadInFlight = mutableSetOf<String>()
    private val chatPreferences =
        chatPreferenceStore.chatPreferences(roomId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ChatRoomPreferences())
    val uiState: StateFlow<ChatDetailUiState> =
        combine(chatRepository.messages(roomId), formState, chatPreferences) { messages, form, preferences ->
            ChatDetailUiState(
                messages = messages,
                draft = form.draft,
                errorMessage = form.errorMessage,
                isLoadingOlder = form.isLoadingOlder,
                hasOlderMessages = form.hasOlderMessages,
                quotedMessage = form.quotedMessage,
                searchQuery = form.searchQuery,
                searchResults = form.searchResults,
                isSearching = form.isSearching,
                isUploadingAttachment = form.isUploadingAttachment,
                attachmentCacheStatus = form.attachmentCacheStatus,
                audioPlaybackStatus = form.audioPlaybackStatus,
                isEmojiPanelVisible = form.isEmojiPanelVisible,
                isStickerPanelVisible = form.isStickerPanelVisible,
                isLoadingStickers = form.isLoadingStickers,
                stickerPacks = form.stickerPacks,
                chatPreferences = preferences,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ChatDetailUiState())

    init {
        viewModelScope.launch {
            runCatching {
                chatRepository.refreshMessages(roomId)
            }
        }
    }

    fun onDraftChange(value: String) {
        formState.update { it.copy(draft = value, errorMessage = null) }
    }

    fun toggleEmojiPanel() {
        formState.update {
            it.copy(
                isEmojiPanelVisible = !it.isEmojiPanelVisible,
                isStickerPanelVisible = false,
                errorMessage = null,
            )
        }
    }

    fun toggleStickerPanel() {
        val shouldLoad = !formState.value.isStickerPanelVisible
        formState.update {
            it.copy(
                isStickerPanelVisible = !it.isStickerPanelVisible,
                isEmojiPanelVisible = false,
                errorMessage = null,
            )
        }
        if (shouldLoad) loadStickerPacks()
    }

    fun insertEmoji(emoji: String) {
        if (emoji !in redCodeBuiltInEmoji) return
        formState.update { state ->
            state.copy(draft = state.draft + emoji, errorMessage = null)
        }
    }

    fun sendSticker(sticker: StickerItem) {
        if (formState.value.isUploadingAttachment) return
        val text = formState.value.draft.takeIf { it.isNotBlank() }
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            formState.update {
                it.copy(isStickerPanelVisible = false, isUploadingAttachment = true, errorMessage = null)
            }
            runCatching {
                val upload = emojiRepository?.prepareStickerUpload(sticker)
                if (upload != null) {
                    chatRepository.uploadAndSendAttachment(
                        roomId = roomId,
                        senderId = currentUserId,
                        senderName = currentUserName,
                        file = upload,
                        type = MessagePartType.Image,
                        text = text,
                        quotedMessageId = quotedMessageId,
                    )
                } else {
                    val objectKey = sticker.imageObjectKey?.takeIf { it.isNotBlank() } ?: error("贴纸资源不可用")
                    chatRepository.sendAttachmentReference(
                        roomId = roomId,
                        senderId = currentUserId,
                        senderName = currentUserName,
                        text = text,
                        parts =
                            listOf(
                                MessagePart(
                                    position = 0,
                                    type = MessagePartType.Image,
                                    attachment =
                                        MessageAttachment(
                                            key = objectKey,
                                            name = sticker.attachmentFileName(),
                                            mime = sticker.mime,
                                        ),
                                ),
                            ),
                        quotedMessageId = quotedMessageId,
                    )
                }
            }.onSuccess {
                formState.update {
                    it.copy(draft = "", quotedMessage = null, errorMessage = null, isUploadingAttachment = false)
                }
            }.onFailure { error ->
                formState.update {
                    it.copy(errorMessage = error.message ?: "发送贴纸失败", isUploadingAttachment = false)
                }
            }
        }
    }

    fun loadStickerPacks(force: Boolean = false) {
        if (formState.value.isLoadingStickers) return
        if (!force && formState.value.stickerPacks != redCodeDefaultStickerPacks) return
        viewModelScope.launch {
            formState.update { it.copy(isLoadingStickers = true, errorMessage = null) }
            runCatching {
                emojiRepository?.loadStickerPacks().orEmpty().ifEmpty { redCodeDefaultStickerPacks }
            }.onSuccess { packs ->
                formState.update {
                    it.copy(stickerPacks = packs, isLoadingStickers = false)
                }
            }.onFailure { error ->
                formState.update {
                    it.copy(
                        stickerPacks = redCodeDefaultStickerPacks,
                        isLoadingStickers = false,
                        errorMessage = error.message ?: "表情包加载失败，已使用默认贴纸",
                    )
                }
            }
        }
    }

    fun setChatBackground(backgroundKey: String) {
        updateChatPreferences {
            it.copy(backgroundKey = backgroundKey).normalized()
        }
    }

    fun cycleChatBackground() {
        val options = chatBackgroundOptions.map { it.key }
        val current = chatPreferences.value.backgroundKey
        val next = options[(options.indexOf(current).takeIf { it >= 0 } ?: 0).let { (it + 1) % options.size }]
        setChatBackground(next)
    }

    fun setFontScale(fontScale: Float) {
        updateChatPreferences {
            it.copy(fontScale = fontScale).normalized()
        }
    }

    fun cycleFontScale() {
        val current = chatPreferences.value.fontScale
        val next =
            when {
                current < 0.95f -> 1.0f
                current < 1.15f -> 1.2f
                else -> 0.9f
            }
        setFontScale(next)
    }

    fun toggleEnterToSend() {
        updateChatPreferences {
            it.copy(enterToSend = !it.enterToSend)
        }
    }

    fun toggleAutoDownloadMedia() {
        updateChatPreferences {
            it.copy(autoDownloadMedia = !it.autoDownloadMedia)
        }
    }

    fun autoDownloadMissingAttachments(attachments: List<MessageAttachment>) {
        val pending =
            attachments
                .filter { it.localPath.isNullOrBlank() }
                .distinctBy { it.key }
                .filter { it.key !in autoDownloadInFlight && formState.value.attachmentCacheStatus[it.key] == null }
        if (pending.isEmpty()) return
        viewModelScope.launch {
            pending.forEach { attachment ->
                autoDownloadInFlight += attachment.key
                try {
                    cacheAttachmentNow(attachment)
                } finally {
                    autoDownloadInFlight -= attachment.key
                }
            }
        }
    }

    fun showError(message: String) {
        formState.update { it.copy(errorMessage = message, isUploadingAttachment = false) }
    }

    fun quoteMessage(message: ChatMessage) {
        if (message.isDeleted || message.id.startsWith("local-")) return
        formState.update { it.copy(quotedMessage = message, errorMessage = null) }
    }

    fun clearQuote() {
        formState.update { it.copy(quotedMessage = null) }
    }

    fun onSearchQueryChange(value: String) {
        formState.update {
            it.copy(searchQuery = value, searchResults = emptyList(), errorMessage = null)
        }
    }

    fun clearSearch() {
        formState.update {
            it.copy(searchQuery = "", searchResults = emptyList(), isSearching = false, errorMessage = null)
        }
    }

    fun searchMessages() {
        val query = formState.value.searchQuery
        viewModelScope.launch {
            val normalized = query.trim()
            if (normalized.isBlank()) {
                formState.update {
                    it.copy(searchQuery = "", searchResults = emptyList(), isSearching = false, errorMessage = null)
                }
                return@launch
            }
            formState.update { it.copy(searchQuery = normalized, isSearching = true, errorMessage = null) }
            runCatching {
                chatRepository.searchMessages(roomId = roomId, query = normalized)
            }.onSuccess { results ->
                formState.update { it.copy(searchResults = results, isSearching = false) }
            }.onFailure { error ->
                formState.update {
                    it.copy(searchResults = emptyList(), isSearching = false, errorMessage = error.message ?: "搜索消息失败")
                }
            }
        }
    }

    fun loadOlderMessages() {
        if (formState.value.isLoadingOlder || !formState.value.hasOlderMessages) return
        viewModelScope.launch {
            formState.update { it.copy(isLoadingOlder = true, errorMessage = null) }
            runCatching {
                chatRepository.loadOlderMessages(roomId)
            }.onSuccess { loaded ->
                formState.update { it.copy(isLoadingOlder = false, hasOlderMessages = loaded) }
            }.onFailure { error ->
                formState.update { it.copy(isLoadingOlder = false, errorMessage = error.message ?: "加载历史消息失败") }
            }
        }
    }

    fun sendDraft() {
        val text = formState.value.draft
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            runCatching {
                chatRepository.sendText(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    text = text,
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update { it.copy(draft = "", quotedMessage = null, errorMessage = null) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送失败") }
            }
        }
    }

    fun sendAttachmentReference(
        attachment: MessageAttachment,
        type: MessagePartType = MessagePartType.File,
        text: String? = formState.value.draft,
    ) {
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            runCatching {
                chatRepository.sendAttachmentReference(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    text = text,
                    parts =
                        listOf(
                            MessagePart(
                                position = 0,
                                type = type,
                                attachment = attachment,
                            ),
                        ),
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update { it.copy(draft = "", quotedMessage = null, errorMessage = null) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送附件失败") }
            }
        }
    }

    fun uploadAndSendAttachment(
        file: AttachmentUploadPayload,
        type: MessagePartType,
        text: String? = formState.value.draft,
    ) {
        if (formState.value.isUploadingAttachment) return
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            formState.update { it.copy(isUploadingAttachment = true, errorMessage = null) }
            runCatching {
                chatRepository.uploadAndSendAttachment(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    file = file,
                    type = type,
                    text = text,
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update {
                    it.copy(draft = "", quotedMessage = null, errorMessage = null, isUploadingAttachment = false)
                }
            }.onFailure { error ->
                formState.update {
                    it.copy(errorMessage = error.message ?: "上传附件失败", isUploadingAttachment = false)
                }
            }
        }
    }

    fun onAttachmentPickerCancelled() {
        formState.update { it.copy(isUploadingAttachment = false) }
    }

    fun cacheAttachment(attachment: MessageAttachment) {
        viewModelScope.launch {
            cacheAttachmentNow(attachment)
        }
    }

    fun playOrPauseAudio(attachment: MessageAttachment) {
        val current = formState.value.audioPlaybackStatus[attachment.key]
        if (current?.phase == AudioPlaybackPhase.Playing) {
            audioPlaybackController.pause()
            updateAudioState(attachment.key, current.copy(phase = AudioPlaybackPhase.Paused, message = "已暂停"))
            return
        }
        viewModelScope.launch {
            updateAudioState(attachment.key, AudioPlaybackState(phase = AudioPlaybackPhase.Loading, localPath = current?.localPath))
            runCatching {
                val localPath =
                    current?.localPath?.takeIf { it.isNotBlank() }
                        ?: attachment.localPath?.takeIf { it.isNotBlank() }
                        ?: chatRepository.downloadAndCacheAttachment(roomId = roomId, attachment = attachment).localPath
                        ?: error("音频文件不可用")
                audioPlaybackController.play(localPath) {
                    updateAudioState(
                        attachment.key,
                        AudioPlaybackState(phase = AudioPlaybackPhase.Paused, localPath = localPath, message = "播放完成"),
                    )
                }
                updateAudioState(attachment.key, AudioPlaybackState(phase = AudioPlaybackPhase.Playing, localPath = localPath))
            }.onFailure { error ->
                updateAudioState(
                    attachment.key,
                    AudioPlaybackState(phase = AudioPlaybackPhase.Failed, localPath = current?.localPath, message = error.message ?: "播放失败"),
                )
            }
        }
    }

    fun releaseAudio() {
        audioPlaybackController.stop()
        formState.update { state ->
            state.copy(
                audioPlaybackStatus =
                    state.audioPlaybackStatus.mapValues { (_, playback) ->
                        if (playback.phase == AudioPlaybackPhase.Playing) {
                            playback.copy(phase = AudioPlaybackPhase.Paused, message = "已暂停")
                        } else {
                            playback
                        }
                    },
            )
        }
    }

    fun resendMessage(messageId: String) {
        viewModelScope.launch {
            runCatching {
                chatRepository.resendMessage(messageId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "重试失败") }
            }
        }
    }

    fun deleteMessage(messageId: String) {
        viewModelScope.launch {
            runCatching {
                chatRepository.deleteMessage(roomId = roomId, messageId = messageId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "删除消息失败") }
            }
        }
    }

    fun toggleMessagePinned(message: ChatMessage) {
        viewModelScope.launch {
            runCatching {
                chatRepository.setMessagePinned(roomId = roomId, messageId = message.id, pinned = !message.isPinned)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: if (message.isPinned) "取消置顶失败" else "置顶消息失败") }
            }
        }
    }

    fun toggleThumbReaction(message: ChatMessage) {
        val selected = message.reactions.firstOrNull { it.reactionKey == "👍" }?.hasSelf != true
        viewModelScope.launch {
            runCatching {
                chatRepository.setReaction(roomId = roomId, messageId = message.id, reactionKey = "👍", selected = selected)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新反应失败") }
            }
        }
    }

    fun markRead() {
        viewModelScope.launch {
            chatRepository.markRead(roomId)
        }
    }

    private fun updateAudioState(key: String, playback: AudioPlaybackState) {
        formState.update { state ->
            state.copy(audioPlaybackStatus = state.audioPlaybackStatus + (key to playback))
        }
    }

    private suspend fun cacheAttachmentNow(attachment: MessageAttachment) {
        formState.update {
            it.copy(
                attachmentCacheStatus = it.attachmentCacheStatus + (attachment.key to "缓存中"),
                errorMessage = null,
            )
        }
        runCatching {
            chatRepository.downloadAndCacheAttachment(roomId = roomId, attachment = attachment)
        }.onSuccess { cached ->
            formState.update {
                it.copy(
                    attachmentCacheStatus =
                        it.attachmentCacheStatus + (attachment.key to (cached.localPath ?: "已缓存")),
                )
            }
        }.onFailure { error ->
            formState.update {
                it.copy(
                    attachmentCacheStatus = it.attachmentCacheStatus + (attachment.key to "缓存失败"),
                    errorMessage = error.message ?: "附件缓存失败",
                )
            }
        }
    }

    private fun updateChatPreferences(transform: (ChatRoomPreferences) -> ChatRoomPreferences) {
        viewModelScope.launch {
            chatPreferenceStore.updateChatPreferences(roomId, transform)
        }
    }
}
