package com.redcode.im.androidapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.di.AppContainer
import com.redcode.im.androidapp.ui.theme.RedCodeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container =
            AppContainer(
                environment =
                    RedCodeEnvironment(
                        apiBaseUrl = BuildConfig.REDCODE_API_BASE_URL,
                        wsUrl = BuildConfig.REDCODE_WS_URL,
                    ),
            )
        setContent {
            RedCodeTheme {
                RedCodeApp(container = container)
            }
        }
    }
}
