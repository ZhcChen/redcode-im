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
import com.redcode.im.androidapp.data.media.FileResourceCache
import com.redcode.im.androidapp.data.media.AvatarCacheRepository
import com.redcode.im.androidapp.data.media.HttpAvatarRemoteDataSource
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.data.preferences.UserPreferenceStore
import com.redcode.im.androidapp.data.rooms.HttpRoomRemoteDataSource
import com.redcode.im.androidapp.data.rooms.InMemoryRoomRepository
import com.redcode.im.androidapp.data.rooms.RemoteRoomRepository
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.RemoteSettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
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
    val chatRepository: ChatRepository =
        if (useRemoteChat && localChatRepository != null) {
            CachedRemoteChatRepository(
                remoteDataSource = HttpChatRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
                localRepository = localChatRepository,
                attachmentFileCache = attachmentFileCache,
            )
        } else if (useRemoteChat) {
            RemoteChatRepository(
                remoteDataSource = HttpChatRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
                attachmentFileCache = attachmentFileCache,
            )
        } else {
            InMemoryChatRepository()
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
    val roomRepository: RoomRepository =
        if (useRemoteRooms && localRoomRepository != null) {
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
        },
    val settingsRepository: SettingsRepository =
        if (useRemoteSettings) {
            RemoteSettingsRepository(APIClient(environment))
        } else {
            InMemorySettingsRepository()
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
            )
        } else {
            null
        },
) {
    suspend fun clearLocalSessionState() {
        webSocketClient?.disconnect()
        chatRepository.clearLocalState()
        contactsRepository.clearLocalState()
        roomRepository.clearLocalState()
        attachmentFileCache?.clear()
        avatarCacheRepository?.clear()
    }
}
