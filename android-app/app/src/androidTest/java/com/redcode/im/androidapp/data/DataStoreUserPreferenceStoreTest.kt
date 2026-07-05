package com.redcode.im.androidapp.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.redcode.im.androidapp.data.preferences.DataStoreUserPreferenceStore
import kotlinx.coroutines.flow.first
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
}
