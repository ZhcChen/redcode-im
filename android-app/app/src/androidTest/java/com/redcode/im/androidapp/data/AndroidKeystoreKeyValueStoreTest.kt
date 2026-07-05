package com.redcode.im.androidapp.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.redcode.im.androidapp.data.auth.AndroidKeystoreKeyValueStore
import java.security.KeyStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidKeystoreKeyValueStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val preferencesName = "redcode_secure_auth_test"
    private val keyAlias = "redcode_im_auth_session_test_${System.nanoTime()}"

    @Before
    fun setUp() {
        context.deleteSharedPreferences(preferencesName)
    }

    @After
    fun tearDown() {
        context.deleteSharedPreferences(preferencesName)
        KeyStore.getInstance("AndroidKeyStore").apply {
            load(null)
            if (containsAlias(keyAlias)) deleteEntry(keyAlias)
        }
    }

    @Test
    fun putString_encryptsAtRestAndDecryptsOnRead() {
        val store = AndroidKeystoreKeyValueStore(context, preferencesName, keyAlias)

        store.putString("auth_session", "plain-token")
        val raw =
            context
                .getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .getString("auth_session", null)

        assertNotEquals("plain-token", raw)
        assertTrue(raw!!.contains(":"))
        assertEquals("plain-token", store.getString("auth_session"))
    }

    @Test
    fun putString_overwritesAndRemoveClearsValue() {
        val store = AndroidKeystoreKeyValueStore(context, preferencesName, keyAlias)

        store.putString("auth_session", "first")
        store.putString("auth_session", "second")
        store.remove("auth_session")

        assertNull(store.getString("auth_session"))
    }

    @Test
    fun getString_discardsCorruptedStoredPayload() {
        val store = AndroidKeystoreKeyValueStore(context, preferencesName, keyAlias)
        context
            .getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString("auth_session", "not-encrypted")
            .commit()

        assertNull(store.getString("auth_session"))
        assertNull(
            context
                .getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .getString("auth_session", null),
        )
    }
}
