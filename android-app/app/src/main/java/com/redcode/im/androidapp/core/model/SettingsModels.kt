package com.redcode.im.androidapp.core.model

data class AppSettings(
    val appName: String = "RedCode IM",
    val notificationEnabled: Boolean = true,
    val darkModeEnabled: Boolean = false,
    val chatBackground: String? = null,
)
