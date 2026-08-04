package com.redcode.im.androidapp.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.redcode.im.androidapp.core.model.ChatRoomPreferences
import com.redcode.im.androidapp.data.preferences.DataStoreUserPreferenceStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DataStoreUserPreferenceStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun setAcceptedTerms_persistsBooleanPreference() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)

            store.setAcceptedTerms(false)
            assertEquals(false, store.acceptedTerms.first())

            store.setAcceptedTerms(true)
            assertEquals(true, store.acceptedTerms.first())
        }

    @Test
    fun chatPreferences_persistPerRoom() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)
            val roomA = "room-a-${System.nanoTime()}"
            val roomB = "room-b-${System.nanoTime()}"

            store.setChatPreferences(
                roomA,
                ChatRoomPreferences(
                    backgroundKey = "warm",
                    fontScale = 1.2f,
                    enterToSend = true,
                    autoDownloadMedia = true,
                ),
            )

            assertEquals("warm", store.chatPreferences(roomA).first().backgroundKey)
            assertEquals(1.2f, store.chatPreferences(roomA).first().fontScale, 0.001f)
            assertEquals(true, store.chatPreferences(roomA).first().enterToSend)
            assertEquals(true, store.chatPreferences(roomA).first().autoDownloadMedia)
            assertEquals(ChatRoomPreferences(), store.chatPreferences(roomB).first())
        }

    @Test
    fun chatPreferences_normalizeInvalidValuesBeforePersisting() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)
            val roomId = "room-normalized-${System.nanoTime()}"

            store.setChatPreferences(
                roomId,
                ChatRoomPreferences(backgroundKey = "unknown", fontScale = 9.9f),
            )

            val preferences = store.chatPreferences(roomId).first()
            assertEquals(ChatRoomPreferences.DEFAULT_BACKGROUND_KEY, preferences.backgroundKey)
            assertEquals(ChatRoomPreferences.MAX_FONT_SCALE, preferences.fontScale, 0.001f)
        }

    @Test
    fun chatPreferences_corruptJsonFallsBackToDefault() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)
            val roomId = "room-corrupt-${System.nanoTime()}"

            store.setRawChatPreferencesForTesting(roomId, "{not-json")

            assertEquals(ChatRoomPreferences(), store.chatPreferences(roomId).first())
        }

    @Test
    fun chatPreferences_updateMergesConcurrentChanges() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)
            val roomId = "room-update-${System.nanoTime()}"
            store.setChatPreferences(roomId, ChatRoomPreferences(backgroundKey = "warm"))

            val enterJob =
                launch {
                    store.updateChatPreferences(roomId) { it.copy(enterToSend = true) }
                }
            val autoDownloadJob =
                launch {
                    store.updateChatPreferences(roomId) { it.copy(autoDownloadMedia = true) }
                }
            enterJob.join()
            autoDownloadJob.join()

            val preferences = store.chatPreferences(roomId).first()
            assertEquals("warm", preferences.backgroundKey)
            assertEquals(true, preferences.enterToSend)
            assertEquals(true, preferences.autoDownloadMedia)
        }

    @Test
    fun chatPreferences_specialRoomIdsDoNotCollide() =
        runTest {
            val store = DataStoreUserPreferenceStore(context)
            val suffix = System.nanoTime()
            val roomWithSlash = "room/$suffix"
            val roomWithoutSlash = "room$suffix"

            store.setChatPreferences(roomWithSlash, ChatRoomPreferences(backgroundKey = "warm"))
            store.setChatPreferences(roomWithoutSlash, ChatRoomPreferences(backgroundKey = "blue"))

            assertEquals("warm", store.chatPreferences(roomWithSlash).first().backgroundKey)
            assertEquals("blue", store.chatPreferences(roomWithoutSlash).first().backgroundKey)
        }
}
