package com.redcode.im.androidapp.di

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.auth.AuthRepository
import com.redcode.im.androidapp.data.auth.AuthSessionStore
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import com.redcode.im.androidapp.data.auth.InMemoryAuthSessionStore
import com.redcode.im.androidapp.data.auth.RemoteAuthRepository
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.data.chat.RemoteChatRepository
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.contacts.HttpFriendRemoteDataSource
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.contacts.RemoteContactsRepository
import com.redcode.im.androidapp.data.emoji.EmojiRepository
import com.redcode.im.androidapp.data.emoji.HttpEmojiRemoteDataSource
import com.redcode.im.androidapp.data.emoji.InMemoryEmojiRepository
import com.redcode.im.androidapp.data.emoji.RemoteEmojiRepository
import com.redcode.im.androidapp.data.media.FileResourceCache
import com.redcode.im.androidapp.data.media.AvatarCacheRepository
import com.redcode.im.androidapp.data.media.HttpAvatarRemoteDataSource
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.data.preferences.UserPreferenceStore
import com.redcode.im.androidapp.data.rooms.HttpRoomRemoteDataSource
import com.redcode.im.androidapp.data.rooms.InMemoryRoomRepository
import com.redcode.im.androidapp.data.rooms.E2eeAwareRoomRepository
import com.redcode.im.androidapp.data.rooms.RemoteRoomRepository
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.RemoteSettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
import com.redcode.im.androidapp.e2ee.E2eeCommandClient
import com.redcode.im.androidapp.e2ee.E2eeCommandSessionCore
import com.redcode.im.androidapp.e2ee.E2eeDeviceLifecycle
import com.redcode.im.androidapp.e2ee.E2eeDeviceManager
import com.redcode.im.androidapp.e2ee.E2eeDirectMessageCoordinator
import com.redcode.im.androidapp.e2ee.E2eeIncomingMessageResolver
import com.redcode.im.androidapp.e2ee.E2eeAttachmentMessageRouter
import com.redcode.im.androidapp.e2ee.E2eeOutgoingTextRouter
import com.redcode.im.androidapp.e2ee.E2eeSecureStateStore
import com.redcode.im.androidapp.e2ee.E2eeSessionLifecycle
import com.redcode.im.androidapp.e2ee.E2eeRoomEventCoordinator
import com.redcode.im.androidapp.e2ee.E2eeRoomEventHandling
import com.redcode.im.androidapp.e2ee.PlaintextE2eeRoomEventHandler
import com.redcode.im.androidapp.e2ee.HttpE2eeMlsApi
import com.redcode.im.androidapp.e2ee.IncomingChatMessageResolver
import com.redcode.im.androidapp.e2ee.OutgoingTextMessageRouter
import com.redcode.im.androidapp.e2ee.PlaintextIncomingMessageResolver
import com.redcode.im.androidapp.e2ee.PlaintextOutgoingTextMessageRouter
import com.redcode.im.androidapp.e2ee.AttachmentMessageRouter
import com.redcode.im.androidapp.e2ee.PlaintextAttachmentMessageRouter
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.persistence.CachedRemoteRoomRepository
import com.redcode.im.androidapp.persistence.CachedRemoteChatRepository
import com.redcode.im.androidapp.persistence.CachedRemoteContactsRepository
import com.redcode.im.androidapp.persistence.RoomChatRepository
import com.redcode.im.androidapp.persistence.RoomContactsRepository
import com.redcode.im.androidapp.persistence.RoomGroupRepository
import com.redcode.im.androidapp.realtime.RedCodeWebSocketClient
import com.redcode.im.androidapp.realtime.RealtimeEventProcessor
import com.redcode.im.androidapp.realtime.RoomRealtimeChatCache
import com.redcode.im.androidapp.feature.settings.E2eeDeviceManagementViewModel

class AppContainer(
    val environment: RedCodeEnvironment,
    useRemoteAuth: Boolean = false,
    useRemoteSettings: Boolean = useRemoteAuth,
    useRemoteChat: Boolean = useRemoteAuth,
    useRemoteContacts: Boolean = useRemoteAuth,
    useRemoteRooms: Boolean = useRemoteAuth,
    authSessionStore: AuthSessionStore = InMemoryAuthSessionStore(),
    private val localChatRepository: RoomChatRepository? = null,
    private val localContactsRepository: RoomContactsRepository? = null,
    private val localRoomRepository: RoomGroupRepository? = null,
    private val attachmentFileCache: FileResourceCache? = null,
    private val avatarFileCache: FileResourceCache? = null,
    private val emojiFileCache: FileResourceCache? = null,
    e2eeSecureStateStore: E2eeSecureStateStore? = null,
    e2eeDeviceLabel: String = "Android",
    e2eeSessionLifecycleOverride: E2eeSessionLifecycle? = null,
    chatRepositoryOverride: ChatRepository? = null,
    val userPreferenceStore: UserPreferenceStore = InMemoryUserPreferenceStore(),
    val authRepository: AuthRepository =
        if (useRemoteAuth) {
            RemoteAuthRepository(
                remoteDataSource = HttpAuthRemoteDataSource(APIClient(environment)),
                sessionStore = authSessionStore,
            )
        } else {
            InMemoryAuthRepository()
        },
    val contactsRepository: ContactsRepository =
        if (useRemoteContacts && localContactsRepository != null) {
            CachedRemoteContactsRepository(
                remoteDataSource = HttpFriendRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
                localRepository = localContactsRepository,
            )
        } else if (useRemoteContacts) {
            RemoteContactsRepository(
                remoteDataSource = HttpFriendRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
            )
        } else {
            InMemoryContactsRepository()
        },
    roomRepositoryOverride: RoomRepository? = null,
    val settingsRepository: SettingsRepository =
        if (useRemoteSettings) {
            RemoteSettingsRepository(APIClient(environment))
        } else {
            InMemorySettingsRepository()
        },
    val emojiRepository: EmojiRepository =
        if (useRemoteChat && emojiFileCache != null) {
            RemoteEmojiRepository(
                remoteDataSource = HttpEmojiRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
                cache = emojiFileCache,
            )
        } else {
            InMemoryEmojiRepository()
        },
    val avatarCacheRepository: AvatarCacheRepository? =
        avatarFileCache?.let { cache ->
            AvatarCacheRepository(
                remoteDataSource = HttpAvatarRemoteDataSource(APIClient(environment)),
                cache = cache,
            )
        },
    val webSocketClient: RedCodeWebSocketClient? =
        if (useRemoteChat) {
            RedCodeWebSocketClient(environment)
        } else {
            null
        },
) {
    private val e2eeGraph =
        e2eeSecureStateStore?.let { secureState ->
            val api = HttpE2eeMlsApi(APIClient(environment))
            val command = E2eeCommandClient()
            val deviceLifecycle = E2eeDeviceLifecycle(secureState, api, command)
            E2eeGraph(
                sessionLifecycle =
                    e2eeSessionLifecycleOverride
                        ?: E2eeSessionLifecycle(settingsRepository, deviceLifecycle, secureState, e2eeDeviceLabel),
                coordinator = E2eeDirectMessageCoordinator(secureState, deviceLifecycle, api, E2eeCommandSessionCore(command)),
                deviceManager = E2eeDeviceManager(secureState, api),
            )
        }

    private val incomingMessageResolver: IncomingChatMessageResolver =
        e2eeGraph?.let { graph ->
            E2eeIncomingMessageResolver(
                session = authRepository.session,
                e2eeStatus = graph.sessionLifecycle.status,
                decryptor = graph.coordinator,
                deviceLabel = e2eeDeviceLabel,
            )
        } ?: PlaintextIncomingMessageResolver

    private val outgoingTextRouter: OutgoingTextMessageRouter =
        e2eeGraph?.let { graph ->
            E2eeOutgoingTextRouter(
                session = authRepository.session,
                e2eeStatus = graph.sessionLifecycle.status,
                sender = graph.coordinator,
                deviceLabel = e2eeDeviceLabel,
            )
        } ?: PlaintextOutgoingTextMessageRouter

    private val attachmentMessageRouter: AttachmentMessageRouter =
        e2eeGraph?.let { graph ->
            E2eeAttachmentMessageRouter(
                session = authRepository.session,
                e2eeStatus = graph.sessionLifecycle.status,
                coordinator = graph.coordinator,
                deviceLabel = e2eeDeviceLabel,
            )
        } ?: PlaintextAttachmentMessageRouter

    private val e2eeRoomEvents: E2eeRoomEventHandling =
        e2eeGraph?.let { graph ->
            E2eeRoomEventCoordinator(
                session = authRepository.session,
                status = graph.sessionLifecycle.status,
                coordinator = graph.coordinator,
            )
        } ?: PlaintextE2eeRoomEventHandler

    private val baseRoomRepository: RoomRepository =
        roomRepositoryOverride
            ?: if (useRemoteRooms && localRoomRepository != null) {
                CachedRemoteRoomRepository(
                    remoteDataSource = HttpRoomRemoteDataSource(APIClient(environment)),
                    session = authRepository.session,
                    localRepository = localRoomRepository,
                )
            } else if (useRemoteRooms) {
                RemoteRoomRepository(
                    remoteDataSource = HttpRoomRemoteDataSource(APIClient(environment)),
                    session = authRepository.session,
                )
            } else {
                InMemoryRoomRepository()
            }

    val roomRepository: RoomRepository =
        e2eeGraph?.let { E2eeAwareRoomRepository(baseRoomRepository, e2eeRoomEvents) }
            ?: baseRoomRepository

    val chatRepository: ChatRepository =
        chatRepositoryOverride
            ?: if (useRemoteChat && localChatRepository != null) {
                CachedRemoteChatRepository(
                    remoteDataSource = HttpChatRemoteDataSource(APIClient(environment)),
                    session = authRepository.session,
                    localRepository = localChatRepository,
                    attachmentFileCache = attachmentFileCache,
                    incomingResolver = incomingMessageResolver,
                    outgoingRouter = outgoingTextRouter,
                    attachmentRouter = attachmentMessageRouter,
                )
            } else if (useRemoteChat) {
                RemoteChatRepository(
                    remoteDataSource = HttpChatRemoteDataSource(APIClient(environment)),
                    session = authRepository.session,
                    attachmentFileCache = attachmentFileCache,
                    incomingResolver = incomingMessageResolver,
                    outgoingRouter = outgoingTextRouter,
                    attachmentRouter = attachmentMessageRouter,
                )
            } else {
                InMemoryChatRepository()
            }

    val realtimeEventProcessor: RealtimeEventProcessor? =
        if (useRemoteChat && localChatRepository != null) {
            RealtimeEventProcessor(
                chatCache =
                    RoomRealtimeChatCache(
                        chatRepository = chatRepository,
                        localRepository = localChatRepository,
                    ),
                contactsRepository = contactsRepository,
                currentUserIdProvider = { authRepository.session.value?.user?.id },
                incomingResolver = incomingMessageResolver,
                roomEvents = e2eeRoomEvents,
                refreshRoomMembers = { roomId -> roomRepository.refreshMembers(roomId) },
            )
        } else {
            null
        }

    val e2eeSessionLifecycle: E2eeSessionLifecycle? = e2eeSessionLifecycleOverride ?: e2eeGraph?.sessionLifecycle
    val e2eeDirectMessageCoordinator: E2eeDirectMessageCoordinator? = e2eeGraph?.coordinator
    val e2eeDeviceManager: E2eeDeviceManager? = e2eeGraph?.deviceManager

    fun makeE2eeDeviceManagementViewModel(accountId: String, token: String): E2eeDeviceManagementViewModel? =
        e2eeGraph?.let { graph ->
            E2eeDeviceManagementViewModel(
                accountId = accountId,
                token = token,
                devices = graph.deviceManager,
                lifecycle = graph.sessionLifecycle,
                rooms = roomRepository,
                roomEvents = e2eeRoomEvents,
            )
        }

    suspend fun prepareE2eeSession(accountId: String, token: String) {
        e2eeSessionLifecycle?.onAuthenticated(accountId, token)
    }

    suspend fun refreshE2eeSession() {
        e2eeSessionLifecycle?.onForeground()
    }

    suspend fun clearLocalSessionState() {
        val errors =
            listOf(
                suspend { webSocketClient?.disconnect() },
                suspend { chatRepository.clearLocalState() },
                suspend { contactsRepository.clearLocalState() },
                suspend { roomRepository.clearLocalState() },
                suspend { attachmentFileCache?.clear() },
                suspend { avatarCacheRepository?.clear() },
                suspend { emojiRepository.clearLocalState() },
                suspend { e2eeSessionLifecycle?.onLogout() },
            ).mapNotNull { cleanup ->
                runCatching { cleanup() }.exceptionOrNull()
            }
        if (errors.isNotEmpty()) {
            throw IllegalStateException("本地会话清理部分失败", errors.first())
        }
    }

    private data class E2eeGraph(
        val sessionLifecycle: E2eeSessionLifecycle,
        val coordinator: E2eeDirectMessageCoordinator,
        val deviceManager: E2eeDeviceManager,
    )
}
