package com.redcode.im.androidapp.data.preferences

import kotlinx.coroutines.flow.Flow

interface UserPreferenceStore {
    val acceptedTerms: Flow<Boolean>

    suspend fun setAcceptedTerms(accepted: Boolean)
}
