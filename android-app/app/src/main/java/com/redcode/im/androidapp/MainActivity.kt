package com.redcode.im.androidapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.room.Room
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.auth.AndroidKeystoreKeyValueStore
import com.redcode.im.androidapp.data.auth.SerializedAuthSessionStore
import com.redcode.im.androidapp.data.preferences.DataStoreUserPreferenceStore
import com.redcode.im.androidapp.di.AppContainer
import com.redcode.im.androidapp.persistence.MIGRATION_1_2
import com.redcode.im.androidapp.persistence.RedCodeDatabase
import com.redcode.im.androidapp.persistence.RoomChatRepository
import com.redcode.im.androidapp.persistence.RoomContactsRepository
import com.redcode.im.androidapp.ui.theme.RedCodeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val database =
            Room.databaseBuilder(
                applicationContext,
                RedCodeDatabase::class.java,
                "redcode-im.db",
            )
                .addMigrations(MIGRATION_1_2)
                .build()
        val container =
            AppContainer(
                environment =
                    RedCodeEnvironment(
                        apiBaseUrl = BuildConfig.REDCODE_API_BASE_URL,
                        wsUrl = BuildConfig.REDCODE_WS_URL,
                    ),
                useRemoteAuth = BuildConfig.REDCODE_USE_REMOTE_AUTH,
                authSessionStore =
                    SerializedAuthSessionStore(
                        AndroidKeystoreKeyValueStore(applicationContext),
                    ),
                localChatRepository = RoomChatRepository(database.chatDao()),
                localContactsRepository = RoomContactsRepository(database.contactDao()),
                userPreferenceStore = DataStoreUserPreferenceStore(applicationContext),
            )
        setContent {
            RedCodeTheme {
                RedCodeApp(container = container)
            }
        }
    }
}
