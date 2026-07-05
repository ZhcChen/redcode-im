package com.redcode.im.androidapp.data.preferences

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.redCodePreferences by preferencesDataStore(name = "redcode_preferences")

class DataStoreUserPreferenceStore(
    context: Context,
) : UserPreferenceStore {
    private val dataStore = context.applicationContext.redCodePreferences

    override val acceptedTerms: Flow<Boolean> =
        dataStore.data.map { preferences ->
            preferences[ACCEPTED_TERMS_KEY] ?: false
        }

    override suspend fun setAcceptedTerms(accepted: Boolean) {
        dataStore.edit { preferences ->
            preferences[ACCEPTED_TERMS_KEY] = accepted
        }
    }

    companion object {
        private val ACCEPTED_TERMS_KEY = booleanPreferencesKey("accepted_terms")
    }
}
