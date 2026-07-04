package com.redcode.im.androidapp.di

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.auth.AuthRepository
import com.redcode.im.androidapp.data.auth.InMemoryAuthRepository
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.chat.InMemoryChatRepository
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository

class AppContainer(
    val environment: RedCodeEnvironment,
    val authRepository: AuthRepository = InMemoryAuthRepository(),
    val chatRepository: ChatRepository = InMemoryChatRepository(),
    val contactsRepository: ContactsRepository = InMemoryContactsRepository(),
    val settingsRepository: SettingsRepository = InMemorySettingsRepository(),
)
