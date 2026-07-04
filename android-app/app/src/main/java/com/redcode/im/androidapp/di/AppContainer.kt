package com.redcode.im.androidapp.di

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.auth.AuthRepository
import com.redcode.im.androidapp.data.auth.HttpAuthRemoteDataSource
import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import com.redcode.im.androidapp.data.auth.InMemoryAuthSessionStore
import com.redcode.im.androidapp.data.auth.RemoteAuthRepository
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
import com.redcode.im.androidapp.network.APIClient

class AppContainer(
    val environment: RedCodeEnvironment,
    useRemoteAuth: Boolean = false,
    val authRepository: AuthRepository =
        if (useRemoteAuth) {
            RemoteAuthRepository(
                remoteDataSource = HttpAuthRemoteDataSource(APIClient(environment)),
                sessionStore = InMemoryAuthSessionStore(),
            )
        } else {
            InMemoryAuthRepository()
        },
    val chatRepository: ChatRepository = InMemoryChatRepository(),
    val contactsRepository: ContactsRepository = InMemoryContactsRepository(),
    val settingsRepository: SettingsRepository = InMemorySettingsRepository(),
)
