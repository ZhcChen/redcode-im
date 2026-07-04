package com.redcode.im.androidapp.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val RedCodeRed = Color(0xFFE53935)
private val RedCodeColorScheme: ColorScheme =
    lightColorScheme(
        primary = RedCodeRed,
        onPrimary = Color.White,
        secondary = Color(0xFFB71C1C),
        background = Color(0xFFFFFBFE),
        surface = Color.White,
    )

@Composable
fun RedCodeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = RedCodeColorScheme,
        content = content,
    )
}
