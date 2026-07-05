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
import com.redcode.im.androidapp.data.preferences.InMemoryUserPreferenceStore
import com.redcode.im.androidapp.data.preferences.UserPreferenceStore
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.RemoteSettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.persistence.CachedRemoteChatRepository
import com.redcode.im.androidapp.persistence.CachedRemoteContactsRepository
import com.redcode.im.androidapp.persistence.RoomChatRepository
import com.redcode.im.androidapp.persistence.RoomContactsRepository

class AppContainer(
    val environment: RedCodeEnvironment,
    useRemoteAuth: Boolean = false,
    useRemoteSettings: Boolean = useRemoteAuth,
    useRemoteChat: Boolean = useRemoteAuth,
    useRemoteContacts: Boolean = useRemoteAuth,
    authSessionStore: AuthSessionStore = InMemoryAuthSessionStore(),
    localChatRepository: RoomChatRepository? = null,
    localContactsRepository: RoomContactsRepository? = null,
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
            )
        } else if (useRemoteChat) {
            RemoteChatRepository(
                remoteDataSource = HttpChatRemoteDataSource(APIClient(environment)),
                session = authRepository.session,
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
    val settingsRepository: SettingsRepository =
        if (useRemoteSettings) {
            RemoteSettingsRepository(APIClient(environment))
        } else {
            InMemorySettingsRepository()
        },
)
