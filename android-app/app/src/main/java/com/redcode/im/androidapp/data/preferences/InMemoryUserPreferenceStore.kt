package com.redcode.im.androidapp.data.preferences

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemoryUserPreferenceStore(
    initialAcceptedTerms: Boolean = false,
) : UserPreferenceStore {
    private val accepted = MutableStateFlow(initialAcceptedTerms)
    override val acceptedTerms = accepted.asStateFlow()

    override suspend fun setAcceptedTerms(accepted: Boolean) {
        this.accepted.value = accepted
    }
}
